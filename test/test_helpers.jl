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
