module Structures

export FPNode, HeaderTable, HeaderTableEntry, find_child

"""
    FPNode{T}

Node trong FP-Tree. Dùng Vector thay Dict cho children để giảm bộ nhớ.
Với dataset dày đặc, branching factor thường nhỏ nên scan tuần tự nhanh hơn Dict.
"""
mutable struct FPNode{T}
    item::T
    count::Int
    parent::Union{FPNode{T}, Nothing}
    children::Union{Vector{FPNode{T}}, Nothing}         # Khởi tạo lazy để tiết kiệm vector
    node_link::Union{FPNode{T}, Nothing}

    function FPNode{T}(item::T, count::Int, parent::Union{FPNode{T}, Nothing}) where T
        new{T}(item, count, parent, nothing, nothing)
    end
end

"""
    find_child(node::FPNode{T}, item::T) → Union{FPNode{T}, Nothing}

Tìm child node có item tương ứng. Trả về nothing nếu không tìm thấy.
Scan tuần tự trên Vector — nhanh khi branching factor nhỏ.
"""
@inline function find_child(node::FPNode{T}, item::T)::Union{FPNode{T}, Nothing} where T
    if node.children === nothing return nothing end
    @inbounds for child in node.children
        if child.item == item
            return child
        end
    end
    return nothing
end

mutable struct HeaderTableEntry{T}
    count::Int
    head::Union{FPNode{T}, Nothing}
    tail::Union{FPNode{T}, Nothing}
    
    function HeaderTableEntry{T}(count::Int) where T
        new{T}(count, nothing, nothing)
    end
end

const HeaderTable{T} = Dict{T, HeaderTableEntry{T}}

end
