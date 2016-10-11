#-------------------------------------------------------------------------------
# Types representing the ply data model

abstract PlyProperty

typealias PropNameList Union{AbstractVector,Tuple}

#--------------------------------------------------
type ArrayProperty{T,Name} <: PlyProperty
    name::Name
    data::Vector{T}
end

#=
# FIXME: Ambiguous constructor
function ArrayProperty{T}(names::PropNameList, data::AbstractVector{T})
    if length(names) != length(T)
        error("Number of property names in $names does not match length($T)")
    end
    ArrayProperty(names, data)
end
=#

ArrayProperty{T}(name::AbstractString, ::Type{T}) = ArrayProperty(String(name), Vector{T}())

Base.resize!(prop::ArrayProperty, len) = resize!(prop.data, len)
Base.push!(prop::ArrayProperty, val) = push!(prop.data, val)

Base.length(prop::ArrayProperty) = length(prop.data)
Base.getindex(prop::ArrayProperty, i) = prop.data[i]

Base.start(prop::ArrayProperty) = start(prop.data)
Base.next(prop::ArrayProperty, state) = next(prop.data, state)
Base.done(prop::ArrayProperty, state) = done(prop.data, state)


#--------------------------------------------------
type ListProperty{S,T} <: PlyProperty
    name::String
    start_inds::Vector{S}
    data::Vector{T}
end
ListProperty{S,T}(name, ::Type{S}, ::Type{T}) = ListProperty(String(name), ones(S,1), Vector{T}())
function ListProperty(name, a::Array)
    prop = ListProperty(String(name), ones(Int32,1), Vector{eltype(a[1])}())
    for ai in a
        push!(prop, ai)
    end
    prop
end

function Base.resize!(prop::ListProperty, len)
    resize!(prop.start_inds, len+1)
    prop.start_inds[1] = 1
end

function Base.push!(prop::ListProperty, list)
    push!(prop.start_inds, prop.start_inds[end]+length(list))
    append!(prop.data, list)
end

Base.length(prop::ListProperty) = length(prop.start_inds)-1
Base.getindex(prop::ListProperty, i) = prop.data[prop.start_inds[i]:prop.start_inds[i+1]-1]

Base.start(prop::ListProperty) = 1
Base.next(prop::ListProperty, state) = (prop[state], state+1)
Base.done(prop::ListProperty, state) = state > length(prop)


#--------------------------------------------------
type Element
    name::String
    len::Int
    properties::Vector{PlyProperty}
end

Element(name::AbstractString) = Element(name, 0, Vector{PlyProperty}())
function Element(name::AbstractString, props::PlyProperty...)
    el = Element(name)
    for prop in props
        push!(el, prop)
    end
    el
end

function Base.push!(elem::Element, prop)
    if isempty(elem.properties)
        elem.len = length(prop)
    elseif elem.len != length(elem.properties[1])
        throw(ErrorException("Property length $(length(prop)) doesn't match element length $(length(elem))"))
    end
    push!(elem.properties, prop)
end

Base.start(elem::Element) = start(elem.properties)
Base.next(elem::Element, state) = next(elem.propertes, state)
Base.done(elem::Element, state) = done(elem.propertes, state)

Base.length(elem::Element) = elem.len

function Base.show(io::IO, elem::Element)
    prop_names = join(["\"$(prop.name)\"" for prop in elem.properties], ", ")
    print(io, "Element \"$(elem.name)\" of length $(length(elem)) with properties [$prop_names]")
end

function Base.getindex(element::Element, prop_name)
    for prop in element.properties
        if prop.name == prop_name
            return prop
        end
    end
    error("property $prop_name not found in Ply element $(element.name)")
end


#--------------------------------------------------
immutable Comment
    comment::String
    location::Int # index of previous element
end

Comment(comment::AbstractString) = Comment(comment, -1)

Base.:(==)(a::Comment, b::Comment) = a.comment == b.comment && a.location == b.location


#--------------------------------------------------
type Ply
    elements::Vector{Element}
    comments::Vector{Comment}
end

Ply() = Ply(Vector{Element}(), Vector{String}())

Base.push!(ply::Ply, el::Element) = push!(ply.elements, el)
Base.push!(ply::Ply, c::Comment) = push!(ply.comments, Comment(c.comment, length(ply.elements)+1))

Base.start(ply::Ply) = start(ply.elements)
Base.next(ply::Ply, state) = next(ply.elements, state)
Base.done(ply::Ply, state) = done(ply.elements, state)

function Base.show(io::IO, ply::Ply)
    print(io, "Ply with elements [$(join(["\"$(elem.name)\"" for elem in ply.elements], ", "))]")
end

function Base.getindex(ply::Ply, elem_name)
    for elem in ply.elements
        if elem.name == elem_name
            return elem
        end
    end
    error("$elem_name not found in Ply element list")
end
