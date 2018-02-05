using CodecZlib

include("model.jl")

function read_archives()
    res = []
    for f in readdir("/var/HumbleGamble2") @when endswith(f, ".json.gz")
        open("/var/HumbleGamble2/$f") do s
            s = GzipDecompressorStream(s)
            data = map(readlines(s)) do line
                line = split(line, '\t')
                parse(Int, car(line)), map(x->parse(f64, x), cdr(line))
            end
            push!(res, data)
            close(s)
        end
    end
    res
end

function complete_data(ds)
    l, h = car(ds[1]), car(ds[end])
    comp = Vector(h - l + 1)

    lastt = 0
    for (t, d) in ds
        t = t - l + 1
        
        for i in lastt+1:t-1
            comp[i] = comp[lastt][:]
            comp[i][8:10] = 0
        end
        
        comp[t] = d
        lastt = t
    end
    
    comp
end

function cherry_pick(ds)
    cherries = []
    for i in 132:length(ds)-1 @when all(length(ds[j]) > 10 && ds[j][10] > 5 for j in i:i-4)
        kline, depth = scale_and_format(ds[i-131:i])
        sellp, buyp  = ds[i+1][[2, 4]]
        push!(cherries, (kline, depth, buyp, sellp))
    end
    cherries
end

function scale_and_format(data)
    kline = Array{f64}(132, 10)
    for i in 1:132
        kline[i, :] = data[i][1:10]
    end

    pl, ph = extrema(kline[:, 3])
    vl, vh = extrema(kline[:, 8:9])

    scale(x, l, h) = (x - l) / (h - l)
    
    kline[:, 1:7] = scale.(kline[:, 1:7], pl, ph)
    kline[:, 8:9] = scale.(kline[:, 8:9], vl, vh)
    kline[:, 10]  = scale.(kline[:, 10], 0, 1000)
    
    depth = Array{f64}(5, 4)
    for i in 1:5
        pb, vb, ps, vs = data[end-5+i]
        depth[i, 1] = scale(pb, pl, ph)
        depth[i, 3] = scale(ps, pl, ph)
        depth[i, 2] = vb / (vb + vs)
        depth[i, 4] = vs / (vb + vs)
    end
    
    kline, depth
end