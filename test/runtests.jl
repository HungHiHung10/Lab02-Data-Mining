using Test

include(joinpath(@__DIR__, "..", "src", "FPGrowth.jl"))
using .FPGrowth

function canonical(results::Dict{Vector{Int}, Int})
    return Dict(sort(collect(itemset)) => support for (itemset, support) in results)
end

function brute_force_frequent_itemsets(transactions::Vector{Vector{Int}}, min_support::Int)
    items = sort(collect(Set(item for transaction in transactions for item in transaction)))
    results = Dict{Vector{Int}, Int}()

    for mask in 1:(Int(1) << length(items)) - 1
        itemset = Int[]
        for index in eachindex(items)
            if (mask & (Int(1) << (index - 1))) != 0
                push!(itemset, items[index])
            end
        end

        support = count(transaction -> all(item -> item in transaction, itemset), transactions)
        if support >= min_support
            results[itemset] = support
        end
    end

    return results
end

function parse_written_results(path::AbstractString)
    parsed = Dict{Vector{Int}, Int}()
    for line in eachline(path)
        stripped = strip(line)
        isempty(stripped) && continue

        parts = split(stripped, "#SUP:")
        @test length(parts) == 2

        itemset = sort(parse.(Int, split(strip(parts[1]))))
        support = parse(Int, strip(parts[2]))
        parsed[itemset] = support
    end
    return parsed
end

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

            output_path = joinpath(@__DIR__, "..", "results", "_test_output_$(file_name)")
            FPGrowth.write_spmf(output_path, base_result)
            @test parse_written_results(output_path) == canonical(expected)
            rm(output_path, force=true)
        end
    end
end

@testset "SPMF reader accepts comma-separated transactions" begin
    input_path = joinpath(@__DIR__, "..", "results", "_test_comma_input.txt")
    output_path = joinpath(@__DIR__, "..", "results", "_test_comma_output.txt")

    open(input_path, "w") do io
        println(io, "1,2,3")
        println(io, "1,2")
        println(io, "2,3")
    end

    transactions = FPGrowth.read_spmf(input_path)
    @test transactions == [[1, 2, 3], [1, 2], [2, 3]]

    results = FPGrowth.fpgrowth(transactions, 2)
    FPGrowth.write_spmf(output_path, results)
    @test parse_written_results(output_path) == Dict([1] => 2, [2] => 3, [3] => 2, [1, 2] => 2, [2, 3] => 2)

    rm(input_path, force=true)
    rm(output_path, force=true)
end
