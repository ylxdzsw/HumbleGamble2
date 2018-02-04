using OhMyJulia
using PyCall

unshift!(PyVector(pyimport("sys")["path"]), @__DIR__)
@pyimport model

