module Utils

export read_spmf, write_spmf

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

end
