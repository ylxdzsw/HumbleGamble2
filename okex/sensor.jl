include("utils.jl")

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
    
    align_time(60, 1) do
        is_delivering() && return
        
        n = floor(time() / 60)
        
        l = last[]
        
        if !isnull(l)
            if !in_same_week(parse(Int, get(l)), n)
                deliver()
                last[] = 0
                l = Nullable()
            end
        end
        
        data = okget("/future_kline.do?symbol=btc_usd&type=1min&contract_type=this_week" * (isnull(l) ? "" : "&since=$(60_000parse(Int, get(l)))"))
        
        for line in sort([[x[1] ÷ 60_000, x[3:6]...] for x in data], by=x->x[1])
            push!(kline, JSON.json(line))
        end
        
        last[] = data[end][1] ÷ 60_000
    end
end
    
# last
@shedule let
    
end