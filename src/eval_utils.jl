"""
Các hàm tiện ích phụ trợ cho quá trình đánh giá (Evaluation).
Tách riêng khỏi FPGrowth.jl để giữ core algorithm sạch sẽ.
"""

function parse_output(filepath)
    results = Set{String}()
    for line in readlines(filepath)
        line = strip(line)
        if isempty(line) continue end
        parts = split(line, "#SUP:")
        if length(parts) == 2
            items = sort([parse(Int, x) for x in split(strip(parts[1]))])
            sup = strip(parts[2])
            canonical_str = join(items, " ") * " - " * sup
            push!(results, canonical_str)
        end
    end
    return results
end

function exe_spmf(config, data_path, output_path, min_sup_ratio)
    cmd = `$(config["java_path"]) -jar $(config["spmf_jar"]) run FPGrowth_itemsets $(data_path) $(output_path) $min_sup_ratio`
    io = IOBuffer()
    run(pipeline(cmd, stdout=io))
    spmf_output = String(take!(io))
    
    spmf_time = 0.0
    spmf_mem_mb = 0.0
    
    for line in split(spmf_output, "\n")
        if occursin("Total time", line)
            m = match(r"~ (\d+) ms", line)
            if m !== nothing spmf_time = parse(Float64, m.captures[1]) / 1000.0 end
        elseif occursin("Max memory usage", line)
            m = match(r": ([\d\.]+) mb", line)
            if m !== nothing spmf_mem_mb = parse(Float64, m.captures[1]) end
        end
    end
    return spmf_time, spmf_mem_mb
end
