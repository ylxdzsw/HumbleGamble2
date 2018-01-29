using Requests
using RedisAlchemy
using JSON
using MD5
using OhMyJulia

set_default_redis_connection(RedisConnectionPool(db=1))

const apikey = RedisString("okex.apikey")[]
const apisec = RedisString("okex.apisec")[]

function okget(path)
    req = Requests.get("https://www.okex.com/api/v1$path", timeout=2)
    status = Requests.statuscode(req)
    status != 200 && throw("okex responses code $status")
    readstring(req) |> JSON.parse
end

function okpost(path; args...)
    str = map(x->join(x, '='), args)
    push!(str, "api_key=$apikey")
    str = join(sort(str), '&')
    sign = uppercase(bytes2hex(md5(str * "&secret_key=$apisec")))
    data = str * "&sign=$sign"
    req = Requests.post("https://www.okex.com/api/v1$path", data=data, headers=Dict("Content-Type"=>"application/x-www-form-urlencoded"), timeout=2)
    status = Requests.statuscode(req)
    status != 200 && throw("okex responses code $status")
    readstring(req) |> JSON.parse
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
            println(STDERR, e)
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

is_delivering() = let now = Dates.unix2datetime(time())
    Dates.dayofweek(now) == 5 && 2 <= Dates.hour(now) < 12
end

function next_deliver_day(t=floor(Int, time() / 60))
    tm = Dates.unix2datetime(60t)
    dw = Dates.dayofweek(tm)
    
    if dw != 5
        d = dw < 5 ? 5 - dw : 12 - dw
        tm + Dates.Day(d)
    elseif Dates.hour(tm) < 8
        tm 
    else
        tm + Dates.Day(7)
    end
end

function start_time(t=floor(Int, time() / 60))
    tm = next_deliver_day(t) - Dates.Day(7)
    tm += Dates.Hour(12 - Dates.hour(tm))
    floor(Int, Dates.datetime2unix(tm) / 3600) * 60
end

function deliver()
    kline = RedisList{String}("okex.kline")
    depth = RedisList{String}("okex.depth")
    last = RedisString("okex.last")
    tid = RedisString("okex.tid")

    deliver_day = next_deliver_day(parse(Int, last[]))
    
    dict = Dict(car(x) => x for x in kline[:])
    for d in depth @when car(d) in keys(dict)
        push!(dict[car(d)], cdr(d)...)
    end
    
    fname = Dates.format(deliver_day, dateformat"yymmdd")
    open("/var/HumbleGamble2/okex_btc_$fname.json", "w") do f
        foreach(x->prt(f, x...), sort(collect(values(dict))))
    end
    
    exec(kline, "del")
    exec(depth, "del")
    last[], tid[] = start_time(), 0
end









