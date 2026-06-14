@testset "FP-Growth correctness on toy datasets" begin
    toy_dir = joinpath(@__DIR__, "..", "data", "toy")
    toy_files = sort(filter(name -> endswith(name, ".txt"), readdir(toy_dir)))

    @test length(toy_files) >= 5

    for file_name in toy_files
        path = joinpath(toy_dir, file_name)
        transactions = FPGrowth.read_spmf(path)
        min_support = ceil(Int, 0.4 * length(transactions))

        expected = brute_force_frequent_itemsets(transactions, min_support)
        base_result = FPGrowth.fpgrowth(transactions, min_support)
        opt_result = FPGrowth.fpgrowth_opt(transactions, min_support)

        @testset "$file_name" begin
            @test canonical(base_result) == canonical(expected)
            @test canonical(opt_result) == canonical(expected)
        end
    end
end

@testset "SPMF reader accepts comma-separated transactions" begin
    input_path = joinpath(@__DIR__, "..", "results", "_test_comma_input.txt")

    open(input_path, "w") do io
        println(io, "1,2,3")
        println(io, "1,2")
        println(io, "2,3")
    end

    transactions = FPGrowth.read_spmf(input_path)
    @test transactions == [[1, 2, 3], [1, 2], [2, 3]]

    rm(input_path, force=true)
end
