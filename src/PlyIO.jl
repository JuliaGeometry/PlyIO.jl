__precompile__()

module PlyIO


#--------------------------------------------------
abstract PlyProperty

type ArrayProperty{T} <: PlyProperty
    name::String
    data::Vector{T}
end
ArrayProperty{T}(name, ::Type{T}) = ArrayProperty(String(name), Vector{T}())

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

Base.:(==)(a::Comment, b::Comment) = a.comment == b.comment && a.location == b.location

#--------------------------------------------------
type Ply
    elements::Vector{Element}
    comments::Vector{Comment}
end

Ply() = Ply(Vector{Element}(), Vector{String}())

Base.push!(ply::Ply, el) = push!(ply.elements, el)
function add_comment!(ply::Ply, str)
    push!(ply.comments, Comment(str, length(ply.elements)+1))
end

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



#-------------------------------------------------------------------------------
# File IO

@enum Format Format_ascii Format_binary_little Format_binary_big

function ply_type(type_name)
    if     type_name == "char"   || type_name == "int8";    return Int8
    elseif type_name == "short"  || type_name == "int16";   return Int16
    elseif type_name == "int"    || type_name == "int32" ;  return Int32
    elseif type_name == "int64";                            return Int64
    elseif type_name == "uchar"  || type_name == "uint8";   return UInt8
    elseif type_name == "ushort" || type_name == "uint16";  return UInt16
    elseif type_name == "uint"   || type_name == "uint32";  return UInt32
    elseif type_name == "uint64";                           return UInt64
    elseif type_name == "float"  || type_name == "float32"; return Float32
    elseif type_name == "double" || type_name == "float64"; return Float64
    else
        error("type_name $type_name unrecognized/unimplemented")
    end
end

ply_type_name(::Type{UInt8})    = "uchar"
ply_type_name(::Type{UInt16})   = "ushort"
ply_type_name(::Type{UInt32})   = "uint"
ply_type_name(::Type{UInt64})   = "uint64"
ply_type_name(::Type{Int8})     = "char"
ply_type_name(::Type{Int16})    = "short"
ply_type_name(::Type{Int32})    = "int"
ply_type_name(::Type{Int64})    = "int64"
ply_type_name(::Type{Float32})  = "float"
ply_type_name(::Type{Float64})  = "double"



function read_binary_value!{T}(stream::IO, prop::ArrayProperty{T}, index)
    prop.data[index] = read(stream, T)
end
function read_binary_value!{S,T}(stream::IO, prop::ListProperty{S,T}, index)
    N = read(stream, S)
    prop.start_inds[index+1] = prop.start_inds[index] + N
    inds = read(stream, T, Int(N))
    append!(prop.data, inds)
end

function parse_ascii{T}(::Type{T}, io::IO)
    # FIXME: sadly unbuffered, will probably have terrible performance.
    buf = UInt8[]
    while !eof(io)
        c = read(io, UInt8)
        if c == UInt8(' ') || c == UInt8('\t') || c == UInt8('\r') || c == UInt8('\n')
            if !isempty(buf)
                break
            end
        else
            push!(buf, c)
        end
    end
    parse(T, String(buf))
end

function read_ascii_value!{T}(stream::IO, prop::ArrayProperty{T}, index)
    prop.data[index] = parse_ascii(T, stream)
end
function read_ascii_value!{S,T}(stream::IO, prop::ListProperty{S,T}, index)
    N = parse_ascii(S, stream)
    prop.start_inds[index+1] = prop.start_inds[index] + N
    for i=1:N
        push!(prop.data, parse_ascii(T, stream))
    end
end


function write_binary_value(stream::IO, prop::ArrayProperty, index)
    write(stream, prop.data[index])
end
function write_binary_value(stream::IO, prop::ListProperty, index)
    len = prop.start_inds[index+1] - prop.start_inds[index]
    write(stream, len)
    esize = sizeof(eltype(prop.data))
    unsafe_write(stream, pointer(prop.data) + esize*(prop.start_inds[index]-1), esize*len)
end

function write_ascii_value(stream::IO, prop::ListProperty, index)
    print(stream, prop.start_inds[index+1] - prop.start_inds[index], ' ')
    for i = prop.start_inds[index]:prop.start_inds[index+1]-1
        if i != prop.start_inds[index]
            write(stream, ' ')
        end
        print(stream, prop.data[i])
    end
end
function write_ascii_value(stream::IO, prop::ArrayProperty, index)
    print(stream, prop.data[index])
end

# Read/write values for an element as binary.  We codegen a version for each
# number of properties so we can unroll the inner loop to get type inference
# for individual properties.  (Could this be done efficiently by mapping over a
# tuple of properties?  Alternatively a generated function would be ok...)
for numprop=1:16
    propnames = [Symbol("p$i") for i=1:numprop]
    @eval function write_binary_values(stream::IO, elen, $(propnames...))
        for i=1:elen
            $([:(write_binary_value(stream, $(propnames[j]), i)) for j=1:numprop]...)
        end
    end
    @eval function read_binary_values!(stream::IO, elen, $(propnames...))
        for i=1:elen
            $([:(read_binary_value!(stream, $(propnames[j]), i)) for j=1:numprop]...)
        end
    end
end
# Fallback for large numbers of properties
function write_binary_values(stream::IO, elen, props...)
    for i=1:elen
        for p in props
            write_binary_value(stream, property, i)
        end
    end
end
function read_binary_values!(stream::IO, elen, props...)
    for i=1:elen
        for p in props
            read_binary_value!(stream, p, i)
        end
    end
end



function read_header(ply_file)
    @assert readline(ply_file) == "ply\n"
    element_name = ""
    element_numel = 0
    element_props = PlyProperty[]
    elements = Element[]
    comments = Comment[]
    format = nothing
    while true
        line = strip(readline(ply_file))
        if line == "end_header"
            break
        elseif startswith(line, "comment")
            push!(comments, Comment(strip(line[8:end]), length(elements)+1))
        elseif startswith(line, "format")
            tok, format_type, format_version = split(line)
            @assert tok == "format"
            @assert format_version == "1.0"
            format = format_type == "ascii"                ? Format_ascii :
                     format_type == "binary_little_endian" ? Format_binary_little :
                     format_type == "binary_big_endian"    ? Format_binary_big :
                     error("Unknown ply format $format_type")
        elseif startswith(line, "element")
            if !isempty(element_name)
                push!(elements, Element(element_name, element_numel, element_props))
                element_props = PlyProperty[]
            end
            tok, element_name, element_numel = split(line)
            @assert tok == "element"
            element_numel = parse(Int,element_numel)
        elseif startswith(line, "property")
            tokens = split(line)
            @assert tokens[1] == "property"
            if tokens[2] == "list"
                count_type_name, type_name, prop_name = tokens[3:end]
                count_type = ply_type(count_type_name)
                type_ = ply_type(type_name)
                push!(element_props, ListProperty(prop_name, ply_type(count_type_name), ply_type(type_name)))
            else
                type_name, prop_name = tokens[2:end]
                push!(element_props, ArrayProperty(prop_name, ply_type(type_name)))
            end
        end
    end
    push!(elements, Element(element_name, element_numel, element_props))
    elements, format, comments
end


function load_ply(io::IO)
    elements, format, comments = read_header(io)
    @assert format != Format_binary_big
    for element in elements
        for prop in element.properties
            resize!(prop, length(element))
        end
        if format == Format_ascii
            for i = 1:length(element)
                for prop in element.properties
                    read_ascii_value!(io, prop, i)
                end
            end
        else # format == Format_binary_little
            read_binary_values!(io, length(element), element.properties...)
        end
    end
    Ply(elements, comments)
end

function load_ply(file_name::AbstractString)
    open(file_name, "r") do fid
        load_ply(fid)
    end
end

function write_header(ply, stream::IO, ascii)
    println(stream, "ply")
    if ascii
        println(stream, "format ascii 1.0")
    else
        endianness = (ENDIAN_BOM == 0x04030201) ? "little" : "big"
        println(stream, "format binary_$(endianness)_endian 1.0")
    end
    commentidx = 1
    for (elemidx,element) in enumerate(ply.elements)
        while commentidx <= length(ply.comments) && ply.comments[commentidx].location == elemidx
            println(stream, "comment ", ply.comments[commentidx].comment)
            commentidx += 1
        end
        println(stream, "element $(element.name) $(length(element))")
        for property in element.properties
            if isa(property, ArrayProperty)
                println(stream, "property $(ply_type_name(eltype(property.data))) $(property.name)")
            else
                println(stream, "property list $(ply_type_name(eltype(property.start_inds))) $(ply_type_name(eltype(property.data))) $(property.name)")
            end
        end
    end
    while commentidx <= length(ply.comments)
        println(stream, "comment ", ply.comments[commentidx].comment)
        commentidx += 1
    end
    println(stream, "end_header")
end

function save_ply(ply, stream::IO; ascii::Bool=false)
    write_header(ply, stream, ascii)
    for element in ply
        if ascii
            for i=1:length(element)
                for (j,property) in enumerate(element.properties)
                    if j != 1
                        write(stream, '\t')
                    end
                    write_ascii_value(stream, property, i)
                end
                println(stream)
            end
        else # binary
            write_binary_values(stream, length(element), element.properties...)
        end
    end
end

function save_ply(ply, file_name::AbstractString; kwargs...)
    open(file_name, "w") do fid
        save_ply(ply, fid; kwargs...)
    end
end

end
