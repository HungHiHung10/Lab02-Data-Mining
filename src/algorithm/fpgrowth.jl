module FPGrowthAlgo

using ..Structures

export fpgrowth, build_fptree, mine_tree

"""
    fpgrowth(transactions::Vector{Vector{T}}, min_support::Int) where T

Thực thi thuật toán FP-Growth, trả về dict gồm itemset => support.
"""
function fpgrowth(transactions::Vector{Vector{T}}, min_support::Int) where T
    frequent_itemsets = Dict{Vector{T}, Int}()
    
    # Lọc và đếm các item
    item_counts = Dict{T, Int}()
    for t in transactions
        for item in t
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    # Loại bỏ các item không thỏa mãn min_support
    freq_items = Dict{T, Int}()
    for (item, count) in item_counts
        if count >= min_support
            freq_items[item] = count
        end
    end
    
    if isempty(freq_items)
        return frequent_itemsets
    end
    
    # Xây dựng Header Table
    header_table = HeaderTable{T}()
    for (item, count) in freq_items
        header_table[item] = Structures.HeaderTableEntry{T}(count)
    end
    
    # Sắp xếp các item trong transaction theo tần suất giảm dần
    sorted_transactions = Vector{Vector{T}}()
    for t in transactions
        filtered_t = [item for item in t if haskey(freq_items, item)]
        if !isempty(filtered_t)
            sort!(filtered_t, by = x -> (-freq_items[x], x))
            push!(sorted_transactions, filtered_t)
        end
    end
    
    # Xây dựng FP-Tree
    root = Structures.FPNode{T}(zero(T), 1, nothing) # item root không quan trọng, ta dùng zero(T) hoặc giá trị mặc định. Trong thuật toán, item root không dùng đến.
    # Để an toàn với mọi T, ta sẽ wrap gốc lại, nhưng để đơn giản ta gán một giá trị null hoặc bất kỳ. 
    # Nhưng vì struct yêu cầu kiểu T, ta sẽ thay đổi logic một chút nếu T không có hàm zero. 
    # Tuy nhiên, ta thường dùng T=Int. Giả sử T có zero(T).
    
    build_fptree!(root, header_table, sorted_transactions, ones(Int, length(sorted_transactions)))
    
    mine_tree!(header_table, min_support, T[], frequent_itemsets)
    
    return frequent_itemsets
end

function build_fptree!(root::Structures.FPNode{T}, header_table::Structures.HeaderTable{T}, transactions::Vector{Vector{T}}, counts::Vector{Int}) where T
    for (i, t) in enumerate(transactions)
        current_node = root
        count = counts[i]
        
        for item in t
            if haskey(current_node.children, item)
                current_node.children[item].count += count
            else
                new_node = Structures.FPNode{T}(item, count, current_node)
                current_node.children[item] = new_node
                
                # Cập nhật node_link
                if header_table[item].head === nothing
                    header_table[item].head = new_node
                    header_table[item].tail = new_node
                else
                    header_table[item].tail.node_link = new_node
                    header_table[item].tail = new_node
                end
            end
            current_node = current_node.children[item]
        end
    end
end

function mine_tree!(header_table::Structures.HeaderTable{T}, min_support::Int, prefix::Vector{T}, frequent_itemsets::Dict{Vector{T}, Int}) where T
    # Sắp xếp các item trong header_table theo support tăng dần
    sorted_items = sort(collect(keys(header_table)), by = x -> (header_table[x].count, x))
    
    for item in sorted_items
        new_prefix = copy(prefix)
        push!(new_prefix, item)
        
        support = header_table[item].count
        frequent_itemsets[new_prefix] = support
        
        # Xây dựng conditional pattern base
        cond_pattern_base = Vector{Vector{T}}()
        cond_counts = Vector{Int}()
        
        node = header_table[item].head
        while node !== nothing
            path = Vector{T}()
            parent = node.parent
            while parent !== nothing && parent.parent !== nothing # không lấy root
                push!(path, parent.item)
                parent = parent.parent
            end
            if !isempty(path)
                reverse!(path)
                push!(cond_pattern_base, path)
                push!(cond_counts, node.count)
            end
            node = node.node_link
        end
        
        # Xây dựng conditional FP-Tree
        cond_item_counts = Dict{T, Int}()
        for (i, path) in enumerate(cond_pattern_base)
            count = cond_counts[i]
            for it in path
                cond_item_counts[it] = get(cond_item_counts, it, 0) + count
            end
        end
        
        cond_header_table = Structures.HeaderTable{T}()
        for (it, c) in cond_item_counts
            if c >= min_support
                cond_header_table[it] = Structures.HeaderTableEntry{T}(c)
            end
        end
        
        if !isempty(cond_header_table)
            cond_root = Structures.FPNode{T}(item, 1, nothing) # item dummy root
            cond_transactions = Vector{Vector{T}}()
            cond_tx_counts = Vector{Int}()
            
            for (i, path) in enumerate(cond_pattern_base)
                filtered_path = [it for it in path if haskey(cond_header_table, it)]
                if !isempty(filtered_path)
                    sort!(filtered_path, by = x -> (-cond_header_table[x].count, x))
                    push!(cond_transactions, filtered_path)
                    push!(cond_tx_counts, cond_counts[i])
                end
            end
            
            build_fptree!(cond_root, cond_header_table, cond_transactions, cond_tx_counts)
            mine_tree!(cond_header_table, min_support, new_prefix, frequent_itemsets)
        end
    end
end

end
