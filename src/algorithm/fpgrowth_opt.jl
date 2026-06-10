module FPGrowthAlgoOpt

using ..Structures

export fpgrowth_opt

"""
    fpgrowth_opt(transactions::Vector{Vector{T}}, min_support::Int) where T

Phiên bản tối ưu Pro (High-Performance Single-threaded):
- Aggressive Single Path Pruning: Tối ưu đường đơn cực mạnh.
- BitArray Filter: Lọc item tốc độ cao.
- Lazy Memory Allocation: Chỉ cấp phát bộ nhớ khi cần.
- Type-stable logic: Giúp Julia biên dịch mã máy tối ưu.
"""
function fpgrowth_opt(transactions::Vector{Vector{T}}, min_support::Int) where T
    frequent_itemsets = Dict{Vector{T}, Int}()
    
    # 1. Count frequencies
    item_counts = Dict{T, Int}()
    for t in transactions
        for item in t
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    # 2. Filter frequent items
    freq_items = Dict{T, Int}()
    max_item = 0
    for (item, count) in item_counts
        if count >= min_support
            freq_items[item] = count
            if T <: Integer max_item = max(max_item, item) end
        end
    end
    
    if isempty(freq_items) return frequent_itemsets end
    
    # 3. Header Table and BitFilter
    header_table = Structures.HeaderTable{T}()
    for (item, count) in freq_items
        header_table[item] = Structures.HeaderTableEntry{T}(count)
    end
    
    use_bitfilter = T <: Integer && max_item < 10^7
    bit_filter = use_bitfilter ? falses(max_item + 1) : nothing
    if use_bitfilter
        for item in keys(freq_items)
            if item >= 0 bit_filter[item + 1] = true end
        end
    end
    
    # 4. Build Initial FP-Tree
    root = Structures.FPNode{T}(zero(T), 0, nothing)
    for t in transactions
        filtered_t = T[]
        for item in t
            if use_bitfilter ? (item >= 0 && item <= max_item && bit_filter[item + 1]) : haskey(freq_items, item)
                push!(filtered_t, item)
            end
        end
        if !isempty(filtered_t)
            sort!(filtered_t, by = x -> (-freq_items[x], x))
            _insert_tree!(root, header_table, filtered_t, 1)
        end
    end
    
    # 5. Mining with Single Path Optimization
    prefix = T[]
    path_buf = T[]
    item_counts_stack = Dict{T, Int}[]
    header_table_stack = Structures.HeaderTable{T}[]
    
    _mine_tree_optimized!(header_table, min_support, prefix, frequent_itemsets, path_buf, 1, item_counts_stack, header_table_stack)
    
    return frequent_itemsets
end

function _mine_tree_optimized!(header_table::Structures.HeaderTable{T}, min_support::Int, prefix::Vector{T}, frequent_itemsets::Dict{Vector{T}, Int}, path_buf::Vector{T}, depth::Int, item_counts_stack::Vector{Dict{T, Int}}, header_table_stack::Vector{Structures.HeaderTable{T}}) where T
    
    # TỐI ƯU QUAN TRỌNG: Single Path Pruning
    if _is_single_path(header_table)
        # Sinh tổ hợp cực nhanh cho đường đơn
        items = sort(collect(keys(header_table)), by = x -> header_table[x].count)
        _generate_combinations_fast!(items, header_table, prefix, frequent_itemsets)
        return
    end

    # Mining thông thường
    sorted_items = sort(collect(keys(header_table)), by = x -> (header_table[x].count, x))
    
    for item in sorted_items
        push!(prefix, item)
        # Đồng nhất itemset đầu ra (Sorted)
        itemset = copy(prefix)
        sort!(itemset)
        frequent_itemsets[itemset] = header_table[item].count
        
        # Lazy initialization cho stack
        if depth > length(item_counts_stack)
            push!(item_counts_stack, Dict{T, Int}())
            push!(header_table_stack, Structures.HeaderTable{T}())
        end
        cond_item_counts = item_counts_stack[depth]
        empty!(cond_item_counts)

        # Xây dựng conditional tree
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
        
        cond_header_table = header_table_stack[depth]
        empty!(cond_header_table)
        for (it, c) in cond_item_counts
            if c >= min_support
                cond_header_table[it] = Structures.HeaderTableEntry{T}(c)
            end
        end
        
        if !isempty(cond_header_table)
            cond_root = Structures.FPNode{T}(zero(T), 0, nothing)
            node = header_table[item].head
            while node !== nothing
                empty!(path_buf)
                parent = node.parent
                while parent !== nothing && parent.parent !== nothing
                    if haskey(cond_header_table, parent.item)
                        push!(path_buf, parent.item)
                    end
                    parent = parent.parent
                end
                if !isempty(path_buf)
                    sort!(path_buf, by = x -> (-cond_header_table[x].count, x))
                    _insert_tree!(cond_root, cond_header_table, path_buf, node.count)
                end
                node = node.node_link
            end
            _mine_tree_optimized!(cond_header_table, min_support, prefix, frequent_itemsets, path_buf, depth + 1, item_counts_stack, header_table_stack)
        end
        pop!(prefix)
    end
end

@inline function _insert_tree!(current::Structures.FPNode{T}, header_table::Structures.HeaderTable{T}, items::Vector{T}, count::Int) where T
    for item in items
        child = Structures.find_child(current, item)
        if child !== nothing
            child.count += count
        else
            new_node = Structures.FPNode{T}(item, count, current)
            if current.children === nothing current.children = Structures.FPNode{T}[] end
            push!(current.children, new_node)
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

function _is_single_path(header_table::Structures.HeaderTable{T}) where T
    nodes = IdDict{Structures.FPNode{T}, Bool}()
    for entry in values(header_table)
        if entry.head === nothing || entry.head !== entry.tail
            return false
        end
        nodes[entry.head] = true
    end

    if isempty(nodes)
        return false
    end

    root_children = 0
    child_counts = IdDict{Structures.FPNode{T}, Int}()
    for node in keys(nodes)
        parent = node.parent
        if parent === nothing
            return false
        elseif parent.parent === nothing
            root_children += 1
        elseif haskey(nodes, parent)
            child_counts[parent] = get(child_counts, parent, 0) + 1
            if child_counts[parent] > 1
                return false
            end
        else
            return false
        end
    end
    return root_children == 1
end

function _generate_combinations_fast!(items::Vector{T}, header_table::Structures.HeaderTable{T}, prefix::Vector{T}, results::Dict{Vector{T}, Int}) where T
    n = length(items)
    # Tối ưu: Dùng mảng tạm để tránh copy prefix nhiều lần
    for i in 1:(2^n - 1)
        new_itemset = copy(prefix)
        min_sup = typemax(Int)
        for j in 1:n
            if (i >> (j-1)) & 1 == 1
                push!(new_itemset, items[j])
                min_sup = min(min_sup, header_table[items[j]].count)
            end
        end
        sort!(new_itemset)
        results[new_itemset] = min_sup
    end
end

end
