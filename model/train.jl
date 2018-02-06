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
        push!(cherries, (kline, depth, i, buyp, sellp))
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

function predict_all!(data)
    klines = Array{f64}(256, 132, 10)
    depths = Array{f64}(256, 5, 4)
    for i in 0:256:length(data)-1
        n = min(256, length(data) - i)
        for j in 1:n
            klines[j, :, :] = data[i+j][1]
            depths[j, :, :] = data[i+j][2]
        end
        
        pred = model.predict(klines, depths)
        
        for j in 1:n
            pacc = accumulate(+, pred[j, :, :] .* .95 .+ .01, 2) # ensure a minimum possiblity
            pacc[:, end] = 1 # ensure absolute 1
            data[i+j] = (data[i+j]..., pacc)
        end
    end
    data
end

function random_walk(data, labels=map(x->fill(0., 5, 5), 1:length(data)))
    function walk(data)
        decisions = []
        vs = [ -35, -10, 0, 10, 35 ]
        stock, balance = 3, 0
        
        for (kline, depth, i, buyp, sellp, pacc) in data
            action = i == data[end][3] ? 3 : let r = rand()
                findfirst(x->x>r, pacc[stock, :])
            end
            
            if action > stock
                balance += 100(vs[action] - vs[stock]) / buyp * 0.9995
            elseif action < stock
                balance -= 100(vs[stock] - vs[action]) / sellp
            end
            
            push!(decisions, (stock, action))
            stock = action
        end
        
        balance, decisions[1:end-1]
    end
    
    balances = []
    
    for i in 30:length(data) @when data[i][3] - data[i-29][3] == 29
        records = [walk(data[i-29:i]) for n in 1:100]
        mid = median(car.(records))
        push!(balances, mid)
        for (balance, decisions) in records
            g = sign(balance - mid)
            for (j, (stock, action)) in enumerate(decisions)
                labels[i-30+j][stock, action] += g
            end
        end
    end
    
    mean(balances), labels
end

function learn(data, labels)
    loss = 0
    
    for i in 0:256:length(data)-1
        n = min(256, length(data) - i)
        
        klines = Array{f32}(n, 132, 10)
        depths = Array{f32}(n, 5, 4)
        grads  = Array{f32}(n, 5, 5)
        
        for j in 1:n
            klines[j, :, :] = data[i+j][1]
            depths[j, :, :] = data[i+j][2]
            grads[j, :, :] = labels[i+j]
        end
        
        loss += model.train(klines, depths, grads) |> sum
    end
    
    loss / length(data)
end

function rewalk!(data, labels)
    data = map(x->x[1:end-1], data)
    predict_all!(data)
    random_walk(data, labels)
end