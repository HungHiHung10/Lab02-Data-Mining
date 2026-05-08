module Structures

export FPNode, HeaderTable

mutable struct FPNode{T}
    item::T
    count::Int
    parent::Union{FPNode{T}, Nothing}
    children::Dict{T, FPNode{T}}
    node_link::Union{FPNode{T}, Nothing}

    function FPNode{T}(item::T, count::Int, parent::Union{FPNode{T}, Nothing}) where T
        new{T}(item, count, parent, Dict{T, FPNode{T}}(), nothing)
    end
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
