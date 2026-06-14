@testset "Benchmark smoke tests" begin
    transactions = FPGrowth.read_spmf(joinpath(@__DIR__, "..", "data", "toy", "test1.txt"))
    min_support = ceil(Int, 0.4 * length(transactions))

    base_result = FPGrowth.fpgrowth(transactions, min_support)
    opt_result = FPGrowth.fpgrowth_opt(transactions, min_support)

    @test !isempty(base_result)
    @test canonical(base_result) == canonical(opt_result)

    output_path = joinpath(@__DIR__, "..", "results", "_test_benchmark_output.txt")
    FPGrowth.write_spmf(output_path, base_result)

    parsed = parse_written_results(output_path)
    @test parsed == canonical(base_result)
    @test all(support >= min_support for support in values(parsed))

    rm(output_path, force=true)
end
