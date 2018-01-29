include("okex.jl")

# heartbeat
@shedule let
    alive = RedisString("okex.alive")
    
    align_time(5) do
        exec(alive, "set", "true", "EX", 7)
    end
end

# kline
@shedule let
    kline = RedisList{String}("okex.kline")
    last = RedisString("okex.last")
    tid = RedisString("okex.tid")
    
    trades = []
    
    exec(last, "setnx", start_time())
    exec(tid, "setnx", 0)
    
    function calc_kline(ts)
        low, high = extrema(map(i"\"price\"", ts))
        tm = sum(map(i"\"amount\"", ts))
        
        i, acc, mp, res = 1, 0, [.25, .5, .75] .* tm, [0., 0., 0.]
        for t in sort(ts, by=i"\"price\"") @when i <= 3
            acc += t["amount"]
            if acc >= mp[i]
                res[i] = t["price"]
                i += 1
            end    
        end
        
        buys  = filter(x->x["type"] == "buy", ts)
        sells = filter(x->x["type"] == "sell", ts)
        
        buym  = mean(map(i"\"price\"", buys))
        sellm = mean(map(i"\"price\"", sells))
        
        buyv  = sum(map(i"\"amount\"", buys))
        sellv = sum(map(i"\"amount\"", sells))
        
        [ts[1]["date"], low, res..., high, buym, sellm, buyv, sellv, length(ts)]
    end
    
    align_time(60, 5) do
        is_delivering() && return
        
        if start_time() != start_time(parse(Int, last[]))
            deliver()
            empty!(trades)
        end
        
        deliverdate = Dates.format(next_deliver_day(), dateformat"yyyy-mm-dd")
        
        # retrive trades
        while floor(Int, time()) % 60 < 55
            k = length(trades) > 10 ? trades[end-10]["tid"] : parse(Int, tid[])
            data = okpost("/future_trades_history.do", symbol="btc_usd", date=deliverdate, since=k) # assume ordered
            
            k = trades[end]["tid"]
            for line in data @when line["tid"] > k
                line["date"] ÷= 60_000
                line["price"] = parse(Float64, line["price"])
                line["amount"] = parse(Int, line["amount"])
                push!(trades, line)
            end
                    
            length(data) < 300 && break
        end
        
        # calc kline
        lt = parse(Int, last[])
        while true
            tms = unique(filter(x->x>=lt, map(i"\"date\"", trades)))
            length(tms) < 3 && break
            p = sort(tms)[2]
            
            tp = filter(x->x["date"] == p, trades)
            tt = length(tp) > 10 ? tp[end-10]["tid"] : tp[1]["tid"]-1
            
            push!(kline, JSON.json(calc_kline(tp)))
            
            last[], tid[] = p, tt
            filter!(x->x["tid"] > tt, trades)
        end
    end
end

# depth
@shedule let
    depth = RedisList{String}("okex.depth")
    last = Ref(floor(Int, time() / 60))
    acc = []
    
    align_time(10, 1, nretry=0) do
        is_delivering() && return
        
        now = floor(Int, time() / 60)
        if last[] != now
            if length(acc) >= 3
                push!(depth, JSON.json([last[], map(mean, zip(acc...))...]))
                last[], acc = now, []
            end
        end
        
        data = okget("/future_depth.do?symbol=btc_usd&contract_type=this_week&size=20&merge=1")
        asks, bids = sort(data["asks"], by=car), sort(data["bids"], by=car)
    
        i, acc = 1, 0
        while i < length(asks)
            acc += cadr(asks[i])
            acc > 100 ? break : (i += 1)
        end
        
        ask1 = car(asks[i])

        i, acc = length(bids), 0
        while i > 1
            acc += cadr(bids[i])
            acc > 100 ? break : (i -= 1)
        end
        
        bid1 = car(bids[i])
        
        askd = sum(cadr, asks)
        bidd = sum(cadr, bids)
        
        push!(acc, (ask1, askd, bid1, bidd))
    end
end





