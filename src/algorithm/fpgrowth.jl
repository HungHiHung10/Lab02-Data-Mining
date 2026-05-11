module FPGrowthAlgo

using ..Structures

export fpgrowth

"""
    fpgrowth(transactions::Vector{Vector{T}}, min_support::Int) where T

Thực thi thuật toán FP-Growth (tối ưu bộ nhớ), trả về dict gồm itemset => support.
"""
function fpgrowth(transactions::Vector{Vector{T}}, min_support::Int) where T
    frequent_itemsets = Dict{Vector{T}, Int}()
    
    # Bước 1: Đếm tần suất mỗi item
    item_counts = Dict{T, Int}()
    for t in transactions
        for item in t
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    # Bước 2: Lọc các item thỏa mãn min_support
    freq_items = Dict{T, Int}()
    for (item, count) in item_counts
        if count >= min_support
            freq_items[item] = count
        end
    end
    
    if isempty(freq_items)
        return frequent_itemsets
    end
    
    # Bước 3: Xây dựng Header Table
    header_table = Structures.HeaderTable{T}()
    for (item, count) in freq_items
        header_table[item] = Structures.HeaderTableEntry{T}(count)
    end
    
    # Bước 4: Sắp xếp, lọc và chèn vào FP-Tree (gộp 2 bước)
    root = Structures.FPNode{T}(zero(T), 0, nothing)
    for t in transactions
        # Lọc + sắp xếp trong 1 bước
        filtered_t = T[]
        for item in t
            if haskey(freq_items, item)
                push!(filtered_t, item)
            end
        end
        if !isempty(filtered_t)
            sort!(filtered_t, by = x -> (-freq_items[x], x))
            # Chèn trực tiếp vào cây (không lưu sorted_transactions)
            _insert_tree!(root, header_table, filtered_t, 1)
        end
    end
    
    # Bước 5: Đào (Mine) cây — dùng buffer tái sử dụng
    prefix = T[]
    path_buf = T[]  # buffer tái sử dụng xuyên suốt đệ quy
    item_counts_stack = Dict{T, Int}[]
    header_table_stack = Structures.HeaderTable{T}[]
    _mine_tree!(header_table, min_support, prefix, frequent_itemsets, path_buf, 1, item_counts_stack, header_table_stack)
    
    return frequent_itemsets
end

"""
Chèn 1 transaction vào FP-Tree. Inline để tránh overhead gọi hàm.
"""
@inline function _insert_tree!(current::Structures.FPNode{T}, header_table::Structures.HeaderTable{T}, items::Vector{T}, count::Int) where T
    for item in items
        child = Structures.find_child(current, item)
        if child !== nothing
            child.count += count
        else
            new_node = Structures.FPNode{T}(item, count, current)
            if current.children === nothing
                current.children = Structures.FPNode{T}[]
            end
            push!(current.children, new_node)
            # Cập nhật linked-list trong header_table
            entry = header_table[item]
            if entry.head === nothing
                entry.head = new_node
                entry.tail = new_node
            else
                entry.tail.node_link = new_node
                entry.tail = new_node
            end
            child = new_node
        end
        current = child
    end
end

"""
Đào (Mine) FP-Tree đệ quy — tối ưu bộ nhớ tối đa.
- Push/pop backtracking cho prefix
- 2-pass trên node_link: pass 1 đếm, pass 2 chèn trực tiếp vào conditional tree
- Tái sử dụng path_buf xuyên suốt toàn bộ đệ quy (0 allocation cho path)
"""
function _mine_tree!(header_table::Structures.HeaderTable{T}, min_support::Int, prefix::Vector{T}, frequent_itemsets::Dict{Vector{T}, Int}, path_buf::Vector{T}, depth::Int, item_counts_stack::Vector{Dict{T, Int}}, header_table_stack::Vector{Structures.HeaderTable{T}}) where T
    # Sắp xếp item theo support tăng dần (chuẩn FP-Growth)
    sorted_items = sort(collect(keys(header_table)), by = x -> (header_table[x].count, x))
    
    for item in sorted_items
        # Backtracking: push trước, pop sau
        push!(prefix, item)
        frequent_itemsets[copy(prefix)] = header_table[item].count
        
        # === PASS 1: Đếm conditional item frequencies (không tạo vector tạm) ===
        if depth > length(item_counts_stack)
            push!(item_counts_stack, Dict{T, Int}())
            push!(header_table_stack, Structures.HeaderTable{T}())
        end
        cond_item_counts = item_counts_stack[depth]
        empty!(cond_item_counts)

        node = header_table[item].head
        while node !== nothing
            cnt = node.count
            parent = node.parent
            while parent !== nothing && parent.parent !== nothing
                cond_item_counts[parent.item] = get(cond_item_counts, parent.item, 0) + cnt
                parent = parent.parent
            end
            node = node.node_link
        end
        
        # Xây dựng conditional header table
        cond_header_table = header_table_stack[depth]
        empty!(cond_header_table)
        for (it, c) in cond_item_counts
            if c >= min_support
                cond_header_table[it] = Structures.HeaderTableEntry{T}(c)
            end
        end
        
        if !isempty(cond_header_table)
            cond_root = Structures.FPNode{T}(zero(T), 0, nothing)
            
            # === PASS 2: Xây dựng conditional FP-tree trực tiếp ===
            # Không tạo paths, cond_transactions, cond_tx_counts — tiết kiệm hàng triệu Vector
            node = header_table[item].head
            while node !== nothing
                # Thu thập path vào buffer tái sử dụng
                empty!(path_buf)
                parent = node.parent
                while parent !== nothing && parent.parent !== nothing
                    if haskey(cond_header_table, parent.item)
                        push!(path_buf, parent.item)
                    end
                    parent = parent.parent
                end
                
                if !isempty(path_buf)
                    reverse!(path_buf)
                    sort!(path_buf, by = x -> (-cond_header_table[x].count, x))
                    # Chèn trực tiếp vào conditional tree (không lưu trung gian)
                    _insert_tree!(cond_root, cond_header_table, path_buf, node.count)
                end
                
                node = node.node_link
            end
            
            # Đệ quy mine conditional tree
            _mine_tree!(cond_header_table, min_support, prefix, frequent_itemsets, path_buf, depth + 1, item_counts_stack, header_table_stack)
        end
        
        # Backtracking: pop
        pop!(prefix)
    end
end

end
