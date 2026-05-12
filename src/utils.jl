module Utils

export read_spmf, write_spmf, parse_output, execute_spmf, transform_spmf

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
    # SPMF 2.42 expects space-separated integers. 
    # Nếu file là CSV (có dấu phẩy), ta sẽ tạo file tạm để SPMF có thể đọc được.
    
    actual_data_path = data_path
    is_temp = false
    
    # Kiểm tra xem file có chứa dấu phẩy không (định dạng CSV)
    if isfile(data_path)
        has_commas = false
        open(data_path, "r") do f
            for line in eachline(f)
                if occursin(",", line)
                    has_commas = true
                end
                break # Chỉ kiểm tra dòng đầu
            end
        end
        
        if has_commas
            actual_data_path = data_path * ".spmf_tmp"
            open(actual_data_path, "w") do out
                open(data_path, "r") do in_f
                    for line in eachline(in_f)
                        println(out, replace(line, "," => " "))
                    end
                end
            end
            is_temp = true
        end
    end

    command = `$(config["java_path"]) -jar $(config["spmf_path"]) run FPGrowth_itemsets $(actual_data_path) $(output_path) $min_sup_ratio`
    
    # Capture both stdout and stderr
    out = IOBuffer()
    err = IOBuffer()
    
    try
        run(pipeline(command, stdout=out, stderr=err))
    catch e
        @warn "SPMF execution failed: $e"
        if is_temp rm(actual_data_path, force=true) end
        return 0.0, 0.0
    end
    
    output = String(take!(out))
    errors = String(take!(err))
    
    # Dọn dẹp file tạm
    if is_temp
        rm(actual_data_path, force=true)
    end

    if occursin("Error", output) || occursin("Exception", output)
        @warn "SPMF reported an error: \n$output"
        return 0.0, 0.0
    end
    
    time_ms = 0.0
    memory_mb = 0.0
    
    # Parse output (SPMF 2.42 format)
    for line in split(output, "\n")
        if occursin("Total time", line)
            m = match(r"~ (\d+) ms", line)
            if m !== nothing 
                time_ms = parse(Float64, m.captures[1]) / 1000.0 
            end
        elseif occursin("Max memory usage", line)
            m = match(r"[:\s]+([\d\.]+) mb"i, line) 
            if m === nothing
                m = match(r"(\d+\.?\d*)\s*mb"i, line)
            end
            if m !== nothing 
                memory_mb = parse(Float64, m.captures[1]) 
            end
        end
    end
    
    return time_ms, memory_mb
end

"""
    transform_spmf(zip_path, extract_dir, raw_data_name, spmf_out_path, logger)

Giải nén và biến đổi dữ liệu categorical sang định dạng SPMF (integer encoding).
Đặc thù cho Connect-4 dataset (42 thuộc tính).
"""
function transform_spmf(zip_path, extract_dir, raw_data_name, spmf_out_path, logger)
    # 1. Giải nén ZIP
    if !isdir(extract_dir)
        mkpath(extract_dir)
    end
    
    # Dùng lệnh hệ thống để giải nén
    # Note: include("src/logger.jl") và using .Logger phải được thực hiện ở ngoài
    printstyled(stdout, "[process] ", color=:blue, bold=true)
    println("Extracting ZIP file...")
    run(`powershell -Command "Expand-Archive -Path $zip_path -DestinationPath $extract_dir -Force"`)

    # 2. Kiểm tra file .Z
    raw_z_path = joinpath(extract_dir, "connect-4.data.Z")
    if isfile(raw_z_path)
        printstyled(stdout, "[process] ", color=:blue, bold=true)
        println("Decompressing .Z file...")
        # gzip -d thường đi kèm với Git hoặc môi trường Unix-like trên Windows
        try
            run(`gzip -d -f $raw_z_path`)
        catch
            # Fallback nếu không có gzip
            printstyled(stdout, "[warning] ", color=:yellow, bold=true)
            println("gzip not found, please ensure 'connect-4.data' is decompressed manually.")
        end
    end

    # 3. Biến đổi dữ liệu sang SPMF
    printstyled(stdout, "[process] ", color=:blue, bold=true)
    println("Converting raw data to SPMF format...")

    data_file_path = joinpath(extract_dir, raw_data_name)
    if !isfile(data_file_path)
        printstyled(stdout, "[fail] ", color=:red, bold=true)
        println("File not found: $data_file_path")
        return
    end

    # Mapping: x=0, o=1, b=2.
    value_map = Dict("x" => 0, "o" => 1, "b" => 2)
    
    open(spmf_out_path, "w") do out_file
        open(data_file_path, "r") do in_file
            for line in eachline(in_file)
                line = strip(line)
                isempty(line) && continue
                
                parts = split(line, ',')
                if length(parts) >= 42
                    items = Int[]
                    for i in 1:42
                        val = strip(parts[i])
                        # Encoding: (attribute_index - 1) * 3 + value
                        if haskey(value_map, val)
                            push!(items, (i - 1) * 3 + value_map[val])
                        end
                    end
                    println(out_file, join(items, " "))
                end
            end
        end
    end

    printstyled(stdout, "[success] ", color=:green, bold=true)
    println("Saved at: $spmf_out_path")
end

end
