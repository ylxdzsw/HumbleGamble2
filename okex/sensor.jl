include("okex.jl")

# heartbeat
@shedule let x = RedisString("okex.alive")
    align_time(5) do
        exec(x, "set", "true", "EX", 7)
    end
end

# kline
@shedule let
    last = SafeRedisString("okex.kline.last")
    kline = RedisList{String}("okex.kline")
    
    align_time(60, 5, nretry=100) do
        is_delivering() && return
        
        l = last[]
        
        if !isnull(l)
            if next_deliver_day() != next_deliver_day(parse(Int, get(l)))
                deliver()
                exec(last, "del")
                l = Nullable()
            end
        end
        
        data = okget("/future_kline.do?symbol=btc_usd&type=1min&contract_type=this_week" * (isnull(l) ? "" : "&since=$(60_000parse(Int, get(l)))"))
        
        data = sort([[x[1] ÷ 60_000, x[3:6]...] for x in data], by=x->car)
        latest = car(data[end-1])
        
        if latest < time() / 60 - 2
            throw("still not updated, fuck okex")
        end
        
        for line in data[1:end-1]
            push!(kline, JSON.json(line))
        end
        
        last[] = latest ÷ 60_000
    end
end
    
# trades
@shedule let
    
    align_time(10, 2, nretry=0) do
        
    end
end

# depth
@shedule let
    depth = RedisList{String}("okex.depth")
    last = floor(Int, time() / 60)
    acc = []
    
    align_time(10, 0, nretry=0) do
        is_delivering() && return
        
        now = floor(Int, time() / 60)
        if last != now
            if length(acc) >= 3
                push!(depth, JSON.json([last, map(mean, zip(acc...))...]))
                last, acc = now, []
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





