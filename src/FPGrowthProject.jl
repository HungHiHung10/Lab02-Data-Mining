module FPGrowthProject

include("structures.jl")
include("algorithm/fpgrowth.jl")
include("utils.jl")

using .Structures
using .FPGrowthAlgo
using .Utils

export fpgrowth, read_spmf, write_spmf

end
