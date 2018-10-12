#-------------------------------------------------------------------------------
# Types representing the ply data model

"""
    plyname(data)

Return the name that `data` is associated with when serialized in a ply file
"""
function plyname
end

const PropNameList = Union{AbstractVector,Tuple}

#--------------------------------------------------
"""
    ArrayProperty(name, T)

A ply `property \$T \$name`, modelled as an abstract vector, with a name which
can be retrieved using `plyname()`.
"""
mutable struct ArrayProperty{T,Name} <: AbstractVector{T}
    name::Name
    data::Vector{T}
end

#=
# FIXME: Ambiguous constructor
function ArrayProperty(names::PropNameList, data::AbstractVector{T}) where {T}
    if length(names) != length(T)
        error("Number of property names in $names does not match length($T)")
    end
    ArrayProperty(names, data)
end
=#

ArrayProperty(name::AbstractString, ::Type{T}) where {T} = ArrayProperty(String(name), Vector{T}())

Base.summary(prop::ArrayProperty) = "$(length(prop))-element $(typeof(prop)) \"$(plyname(prop))\""

# AbstractArray methods
Base.size(prop::ArrayProperty) = size(prop.data)
Base.getindex(prop::ArrayProperty, i::Int) = prop.data[i]
Base.setindex!(prop::ArrayProperty, v, i::Int) = prop.data[i] = v
@compat Base.IndexStyle(::Type{<:ArrayProperty}) = IndexLinear()

# List methods
Base.resize!(prop::ArrayProperty, len) = resize!(prop.data, len)
Base.push!(prop::ArrayProperty, val) = (push!(prop.data, val); prop)

# Ply methods
plyname(prop::ArrayProperty) = prop.name


#--------------------------------------------------
"""
    ListProperty(name, S, T)
    ListProperty(name, list_of_vectors)

A ply `property list \$S \$T \$name`, modelled as a abstract vector of vectors,
with a name which can be retrieved using `plyname()`.
"""
mutable struct ListProperty{S,T} <: AbstractVector{Vector{T}}
    name::String
    start_inds::Vector{Int}
    data::Vector{T}
end

ListProperty(name, ::Type{S}, ::Type{T}) where {S,T} = ListProperty{S,T}(String(name), ones(Int,1), Vector{T}())

function ListProperty(name::AbstractString, a::AbstractVector)
    # Construct list from an array of arrays
    prop = ListProperty(name, Int32, eltype(a[1]))
    foreach(ai->push!(prop,ai), a)
    prop
end

Base.summary(prop::ListProperty) = "$(length(prop))-element $(typeof(prop)) \"$(plyname(prop))\""

# AbstractArray methods
Base.length(prop::ListProperty) = length(prop.start_inds)-1
Base.size(prop::ListProperty) = (length(prop),)
Base.getindex(prop::ListProperty, i::Int) = prop.data[prop.start_inds[i]:prop.start_inds[i+1]-1]
@compat Base.IndexStyle(::Type{<:ListProperty}) = IndexLinear()
# TODO: Do we need Base.setindex!() ?  Hard to provide with above formulation...

# List methods
function Base.resize!(prop::ListProperty, len)
    resize!(prop.start_inds, len+1)
    prop.start_inds[1] = 1
end
function Base.push!(prop::ListProperty, list)
    push!(prop.start_inds, prop.start_inds[end]+length(list))
    append!(prop.data, list)
    prop
end

# Ply methods
plyname(prop::ListProperty) = prop.name


#--------------------------------------------------
"""
    PlyElement(name, [len | props...])

Construct a ply `element \$name \$len`, containing a list of properties with a
name which can be retrieved using `plyname`.  Properties can be accessed with
the array interface, or looked up by indexing with a string.

The expected length `len` is used if it is set, otherwise the length shared by
the property vectors is used.
"""
mutable struct PlyElement
    name::String
    prior_len::Int  # Length as expected, or as read from file
    properties::Vector
end

PlyElement(name::AbstractString, len::Int=-1) = PlyElement(name, len, Vector{Any}())

function PlyElement(name::AbstractString, props::AbstractVector...)
    PlyElement(name, -1, collect(props))
end

function Base.show(io::IO, elem::PlyElement)
    prop_names = join(["\"$(plyname(prop))\"" for prop in elem.properties], ", ")
    print(io, "PlyElement \"$(plyname(elem))\" of length $(length(elem)) with properties [$prop_names]")
end

# Table-like methods
function Base.length(elem::PlyElement)
    # Check that lengths are consistent and return the length
    if elem.prior_len != -1
        return elem.prior_len
    end
    if isempty(elem.properties)
        return 0
    end
    len = length(elem.properties[1])
    if any(prop->len != length(prop), elem.properties)
        proplens = [length(p) for p in elem.properties]
        throw(ErrorException("Element $(plyname(elem)) has inconsistent property lengths: $proplens"))
    end
    return len
end

function Base.getindex(element::PlyElement, prop_name)
    # Get first property with a matching name
    for prop in element.properties
        if plyname(prop) == prop_name
            return prop
        end
    end
    error("property $prop_name not found in Ply element $(plyname(element))")
end

# List methods
if VERSION >= v"0.7"
    Base.iterate(elem::PlyElement, s...) = iterate(elem.properties, s...)
else
    Base.start(elem::PlyElement) = start(elem.properties)
    Base.next(elem::PlyElement, state) = next(elem.propertes, state)
    Base.done(elem::PlyElement, state) = done(elem.propertes, state)
    Base.push!(elem::PlyElement, prop) = (push!(elem.properties, prop); elem)
end

# Ply methods
plyname(elem::PlyElement) = elem.name


#--------------------------------------------------
"""
    PlyComment(string)

A ply comment.
"""
struct PlyComment
    comment::String
    location::Int # index of previous element
end

PlyComment(string::AbstractString) = PlyComment(string, -1)

Base.:(==)(a::PlyComment, b::PlyComment) = a.comment == b.comment && a.location == b.location


#--------------------------------------------------
"""
    Ply()

Container for the contents of a ply file.  This type directly models the
contents of the header.  Ply elements and comments can be added using
`push!()`, elements can be iterated over with the standard iterator
interface, and looked up by indexing with a string.
"""
mutable struct Ply
    elements::Vector{PlyElement}
    comments::Vector{PlyComment}
end

Ply() = Ply(Vector{PlyElement}(), Vector{String}())

function Base.show(io::IO, ply::Ply)
    buf = IOBuffer()
    write_header(ply, buf, true)
    headerstr = String(take!(buf))
    headerstr = replace(strip(headerstr), "\n", "\n ")
    print(io, "$Ply with header:\n $headerstr")
end

# List methods
Base.push!(ply::Ply, el::PlyElement) = (push!(ply.elements, el); ply)
Base.push!(ply::Ply, c::PlyComment) = (push!(ply.comments, PlyComment(c.comment, length(ply.elements)+1)); ply)

# Element search and iteration
function Base.getindex(ply::Ply, elem_name::AbstractString)
    for elem in ply.elements
        if plyname(elem) == elem_name
            return elem
        end
    end
    error("$elem_name not found in Ply element list")
end

Base.length(ply::Ply) = length(ply.elements)
if VERSION >= v"0.7"
    Compat.iterate(ply::Ply, s...) = iterate(ply.elements, s...)
else
    Base.start(ply::Ply) = start(ply.elements)
    Base.next(ply::Ply, state) = next(ply.elements, state)
    Base.done(ply::Ply, state) = done(ply.elements, state)
end
