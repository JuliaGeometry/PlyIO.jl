#-------------------------------------------------------------------------------
# Types representing the ply data model

module Ply

export Property, ArrayProp, ListProp, Element, Comment, Data

abstract Property

typealias PropNameList Union{AbstractVector,Tuple}

#--------------------------------------------------
type ArrayProp{T,Name} <: Property
    name::Name
    data::Vector{T}
end

#=
# FIXME: Ambiguous constructor
function ArrayProp{T}(names::PropNameList, data::AbstractVector{T})
    if length(names) != length(T)
        error("Number of property names in $names does not match length($T)")
    end
    ArrayProp(names, data)
end
=#

ArrayProp{T}(name::AbstractString, ::Type{T}) = ArrayProp(String(name), Vector{T}())

Base.resize!(prop::ArrayProp, len) = resize!(prop.data, len)
Base.push!(prop::ArrayProp, val) = push!(prop.data, val)

Base.length(prop::ArrayProp) = length(prop.data)
Base.getindex(prop::ArrayProp, i) = prop.data[i]

Base.start(prop::ArrayProp) = start(prop.data)
Base.next(prop::ArrayProp, state) = next(prop.data, state)
Base.done(prop::ArrayProp, state) = done(prop.data, state)


#--------------------------------------------------
type ListProp{S,T} <: Property
    name::String
    start_inds::Vector{S}
    data::Vector{T}
end
ListProp{S,T}(name, ::Type{S}, ::Type{T}) = ListProp(String(name), ones(S,1), Vector{T}())
function ListProp(name, a::Array)
    prop = ListProp(String(name), ones(Int32,1), Vector{eltype(a[1])}())
    for ai in a
        push!(prop, ai)
    end
    prop
end

function Base.resize!(prop::ListProp, len)
    resize!(prop.start_inds, len+1)
    prop.start_inds[1] = 1
end

function Base.push!(prop::ListProp, list)
    push!(prop.start_inds, prop.start_inds[end]+length(list))
    append!(prop.data, list)
end

Base.length(prop::ListProp) = length(prop.start_inds)-1
Base.getindex(prop::ListProp, i) = prop.data[prop.start_inds[i]:prop.start_inds[i+1]-1]

Base.start(prop::ListProp) = 1
Base.next(prop::ListProp, state) = (prop[state], state+1)
Base.done(prop::ListProp, state) = state > length(prop)


#--------------------------------------------------
type Element
    name::String
    len::Int
    properties::Vector{Property}
end

Element(name::AbstractString) = Element(name, 0, Vector{Property}())
function Element(name::AbstractString, props::Property...)
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
    error("property $prop_name not found in Data element $(element.name)")
end


#--------------------------------------------------
immutable Comment
    comment::String
    location::Int # index of previous element
end

Comment(comment::AbstractString) = Comment(comment, -1)

Base.:(==)(a::Comment, b::Comment) = a.comment == b.comment && a.location == b.location


#--------------------------------------------------
type Data
    elements::Vector{Element}
    comments::Vector{Comment}
end

Data() = Data(Vector{Element}(), Vector{String}())

Base.push!(ply::Data, el::Element) = push!(ply.elements, el)
Base.push!(ply::Data, c::Comment) = push!(ply.comments, Comment(c.comment, length(ply.elements)+1))

Base.start(ply::Data) = start(ply.elements)
Base.next(ply::Data, state) = next(ply.elements, state)
Base.done(ply::Data, state) = done(ply.elements, state)

function Base.show(io::IO, ply::Data)
    print(io, "Data with elements [$(join(["\"$(elem.name)\"" for elem in ply.elements], ", "))]")
end

function Base.getindex(ply::Data, elem_name)
    for elem in ply.elements
        if elem.name == elem_name
            return elem
        end
    end
    error("$elem_name not found in Data element list")
end

end
