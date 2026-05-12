module Utils

export read_spmf, write_spmf, parse_output, execute_spmf

"""
    read_spmf(filepath::String)

Đọc dataset định dạng SPMF (mỗi dòng là một giao dịch, các item cách nhau bởi khoảng trắng).
Trả về danh sách các giao dịch (Vector{Vector{Int}}).
"""
function read_spmf(filepath::String)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    open(filepath, "r") do file
        for line in eachline(file)
            # Thay thế dấu phẩy bằng khoảng trắng phòng trường hợp file dùng dấu phẩy
            line = replace(line, "," => " ")
            items = split(strip(line))
            if !isempty(items)
                t = [parse(Int, item) for item in items if item != ""]
                push!(transactions, t)
            end
        end
    end
    return transactions
end

"""
    write_spmf(filepath::String, frequent_itemsets::Dict{Vector{Int}, Int})

Ghi kết quả tập phổ biến ra file theo định dạng SPMF (item1 item2 ... #SUP: count).
"""
function write_spmf(filepath::String, frequent_itemsets::Dict{Vector{Int}, Int})
    # Sắp xếp các itemset để đầu ra có tính ổn định
    # Sắp xếp theo chiều dài, sau đó theo từ điển
    sorted_itemsets = sort(collect(keys(frequent_itemsets)), by = x -> (length(x), x))
    
    open(filepath, "w") do file
        for itemset in sorted_itemsets
            support = frequent_itemsets[itemset]
            itemset_str = join(itemset, " ")
            println(file, "$itemset_str #SUP: $support")
        end
    end
end

function parse_output(file_path)
    results = Set{String}()
    for line in readlines(file_path)
        line = strip(line)
        if isempty(line) continue end
        parts = split(line, "#SUP:")
        if length(parts) == 2
            items = sort([parse(Int, x) for x in split(strip(parts[1]))])
            sup = strip(parts[2])
            canonical_string = join(items, " ") * " - " * sup
            push!(results, canonical_string)
        end
    end
    return results
end

function execute_spmf(config, data_path, output_path, min_sup_ratio)
    command = `$(config["java_path"]) -jar $(config["spmf_jar"]) run FPGrowth_itemsets $(data_path) $(output_path) $min_sup_ratio`
    output_buffer = IOBuffer()
    # SPMF in thống kê ra stdout
    run(pipeline(command, stdout=output_buffer))
    output = String(take!(output_buffer))
    
    time_ms = 0.0
    memory_mb = 0.0
    
    for line in split(output, "\n")
        if occursin("Total time", line)
            m = match(r"~ (\d+) ms", line)
            if m !== nothing time_ms = parse(Float64, m.captures[1]) / 1000.0 end
        elseif occursin("Max memory usage", line)
            m = match(r": ([\d\.]+) mb", line)
            if m !== nothing memory_mb = parse(Float64, m.captures[1]) end
        end
    end
    return time_ms, memory_mb
end

end
