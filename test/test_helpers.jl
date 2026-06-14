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

function java_executable()
    configured_path = get(ENV, "JAVA_PATH", "")
    if !isempty(configured_path)
        return configured_path
    end

    windows_java = raw"C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot\bin\java.exe"
    if Sys.iswindows() && isfile(windows_java)
        return windows_java
    end

    java = Sys.which("java")
    java === nothing && error("Java executable not found. Install JDK or set ENV[\"JAVA_PATH\"].")
    return java
end

function spmf_jar_path()
    path = joinpath(@__DIR__, "..", "src", "algorithm", "fpgrowth_spmf.jar")
    isfile(path) || error("SPMF jar not found at $path")
    return path
end

function spmf_reference(input_path::AbstractString, output_path::AbstractString, minsup_ratio::Real)
    mkpath(dirname(output_path))
    rm(output_path, force=true)

    cmd = Cmd([
        java_executable(),
        "-jar",
        spmf_jar_path(),
        "run",
        "FPGrowth_itemsets",
        input_path,
        output_path,
        string(minsup_ratio),
    ])

    read(ignorestatus(cmd), String)

    if !isfile(output_path) || filesize(output_path) == 0
        error("SPMF did not create a non-empty output file: $output_path")
    end

    return parse_written_results(output_path)
end
