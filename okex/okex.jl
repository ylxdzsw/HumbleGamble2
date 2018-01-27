using Requests
using RedisAlchemy
using JSON

set_default_redis_connection(RedisConnectionPool())

function okget(path)
    req = Requests.get("https://www.okex.com/api/v1$path")
    status = Requests.statuscode(req)
    status != 200 && throw("okex responses code $status")
    readstring(req) |> JSON.parse
end

function okpost()
    
end

align_time(f, t=60, phrase=0; nretry=3) = while true
    c = time() - phrase
    r = floor(c / t + 1) * t
    sleep(r - c)
    
    ntrail = 1
    while true
        try
            f()
        catch e
            if ntrail < nretry
                ntrail += 1
                sleep(0.1)
                continue
            else
                rethrow(e)
            end
        end
        break
    end     
end

is_delivering() = let now = now()
    Dates.dayofweek(now) == 5 && 10 <= Dates.hour(now) < 20
end

function in_same_week(a, b)
    
end

function deliver()

end