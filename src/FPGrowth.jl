module FPGrowth

include("structures.jl")
include("algorithm/fpgrowth.jl")
include("algorithm/fpgrowth_opt.jl")
include("utils.jl")

using .Structures
using .FPGrowthAlgo
using .FPGrowthAlgoOpt
using .Utils

export fpgrowth, fpgrowth_opt, read_spmf, write_spmf

end
