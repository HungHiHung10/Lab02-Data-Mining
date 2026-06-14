using Test

include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

include("test_helpers.jl")
include("test_correctness.jl")
include("test_benchmark.jl")
