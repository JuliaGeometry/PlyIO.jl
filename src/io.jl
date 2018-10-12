#-------------------------------------------------------------------------------
# Ply file IO functionality

#--------------------------------------------------
# Header IO

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

ply_type_name(::Type{UInt8})    = "uint8"
ply_type_name(::Type{UInt16})   = "uint16"
ply_type_name(::Type{UInt32})   = "uint32"
ply_type_name(::Type{UInt64})   = "uint64"
ply_type_name(::Type{Int8})     = "int8"
ply_type_name(::Type{Int16})    = "int16"
ply_type_name(::Type{Int32})    = "int32"
ply_type_name(::Type{Int64})    = "int64"
ply_type_name(::Type{Float32})  = "float32"
ply_type_name(::Type{Float64})  = "float64"

ply_type_name(::UInt8)    = "uint8"
ply_type_name(::UInt16)   = "uint16"
ply_type_name(::UInt32)   = "uint32"
ply_type_name(::UInt64)   = "uint64"
ply_type_name(::Int8)     = "int8"
ply_type_name(::Int16)    = "int16"
ply_type_name(::Int32)    = "int32"
ply_type_name(::Int64)    = "int64"
ply_type_name(::Float32)  = "float32"
ply_type_name(::Float64)  = "float64"

const PlyNativeType = Union{UInt8,UInt16,UInt32,UInt64,Int8,Int16,Int32,Int64,Float32,Float64}

ply_type_name(A::AbstractArray{T}) where {T<:PlyNativeType} = ply_type_name(T)

ply_type_name(A::AbstractArray) = !isempty(A) ? ply_type_name(A[1]) :
                                  error("Unknown ply element type name for empty array of type $(typeof(A))")


const _host_is_little_endian = (ENDIAN_BOM == 0x04030201)


function read_header(ply_file)
    firstline = Compat.readline(ply_file)
    if firstline != "ply"
        throw(ErrorException("Expected \"ply\" header, got \"$firstline\""))
    end
    element_name = ""
    element_numel = 0
    element_props = Vector{AbstractVector}()
    elements = PlyElement[]
    comments = PlyComment[]
    format = nothing
    while true
        line = Compat.readline(ply_file)
        if line == "" && eof(ply_file)
            throw(ErrorException("Unexpected end of file reading ply header"))
        elseif line == "end_header"
            break
        elseif startswith(line, "comment")
            push!(comments, PlyComment(strip(line[8:end]), length(elements)+1))
        else
            tokens = split(line)
            length(tokens) > 2 || throw(ErrorException("Bad ply header, line: \"$line\""))
            if tokens[1] == "format"
                length(tokens) == 3 || throw(ErrorException("Bad ply header, line: \"$line\""))
                _, format_type, format_version = tokens
                if format_version != "1.0"
                    throw(ErrorException("Expected ply version 1.0, got $format_version"))
                end
                format = format_type == "ascii"                ? Format_ascii :
                        format_type == "binary_little_endian" ? Format_binary_little :
                        format_type == "binary_big_endian"    ? Format_binary_big :
                        error("Unknown ply format $format_type")
            elseif tokens[1] == "element"
                if !isempty(element_name)
                    push!(elements, PlyElement(element_name, element_numel, element_props))
                    element_props = Vector{AbstractVector}()
                end
                length(tokens) == 3 || throw(ErrorException("Bad ply header, line: \"$line\""))
                _, element_name, element_numel = tokens
                element_numel = parse(Int,element_numel)
            elseif tokens[1] == "property"
                !isempty(element_name) || throw(ErrorException("Bad ply header: property before first element"))
                if tokens[2] == "list"
                    length(tokens) == 5 || throw(ErrorException("Bad ply header, line: \"$line\""))
                    count_type_name, type_name, prop_name = tokens[3:end]
                    count_type = ply_type(count_type_name)
                    type_ = ply_type(type_name)
                    push!(element_props, ListProperty(prop_name, ply_type(count_type_name), ply_type(type_name)))
                else
                    length(tokens) == 3 || throw(ErrorException("Bad ply header, line: \"$line\""))
                    type_name, prop_name = tokens[2:end]
                    push!(element_props, ArrayProperty(prop_name, ply_type(type_name)))
                end
            else
                throw(ErrorException("Bad ply header, line: \"$line\""))
            end
        end
    end
    if !isempty(element_name)
        push!(elements, PlyElement(element_name, element_numel, element_props))
    end
    elements, format, comments
end


function write_header_field(stream::IO, prop::ArrayProperty)
    println(stream, "property $(ply_type_name(prop.data)) $(prop.name)")
end

function write_header_field(stream::IO, prop::ArrayProperty{T,Names}) where {T,Names<:PropNameList}
    for n in prop.name
        println(stream, "property $(ply_type_name(prop.data)) $(n)")
    end
end

function write_header_field(stream::IO, prop::ListProperty{S}) where {S}
    println(stream, "property list $(ply_type_name(S)) $(ply_type_name(prop.data)) $(prop.name)")
end


function write_header(ply, stream::IO, ascii)
    println(stream, "ply")
    if ascii
        println(stream, "format ascii 1.0")
    else
        endianness = _host_is_little_endian ? "little" : "big"
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
            write_header_field(stream, property)
        end
    end
    while commentidx <= length(ply.comments)
        println(stream, "comment ", ply.comments[commentidx].comment)
        commentidx += 1
    end
    println(stream, "end_header")
end


#-------------------------------------------------------------------------------
# ASCII IO for properties and elements

function parse_ascii(::Type{T}, io::IO) where {T}
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

function read_ascii_value!(stream::IO, prop::ArrayProperty{T}, index) where {T}
    prop.data[index] = parse_ascii(T, stream)
end
function read_ascii_value!(stream::IO, prop::ListProperty{S,T}, index) where {S,T}
    N = parse_ascii(S, stream)
    prop.start_inds[index+1] = prop.start_inds[index] + N
    for i=1:N
        push!(prop.data, parse_ascii(T, stream))
    end
end


#-------------------------------------------------------------------------------
# Binary IO for properties and elements

#--------------------------------------------------
# property IO
function read_binary_value!(stream::IO, prop::ArrayProperty{T}, index) where {T}
    prop.data[index] = read(stream, T)
end
function read_binary_value!(stream::IO, prop::ListProperty{S,T}, index) where {S,T}
    N = read(stream, S)
    prop.start_inds[index+1] = prop.start_inds[index] + N
    inds = read!(stream, Vector{T}(undef, Int(N)))
    append!(prop.data, inds)
end

function write_binary_value(stream::IO, prop::ArrayProperty, index)
    write(stream, prop.data[index])
end
function write_binary_value(stream::IO, prop::ListProperty{S}, index) where {S}
    len = prop.start_inds[index+1] - prop.start_inds[index]
    write(stream, convert(S, len))
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
function write_ascii_value(stream::IO, prop::ArrayProperty{<:AbstractArray}, index)
    p = prop.data[index]
    for i = 1:length(p)
        if i != 1
            write(stream, '\t')
        end
        print(stream, p[i])
    end
end


#--------------------------------------------------
# Batched element IO

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

# Optimization: special cases for a single array property within an element
function write_binary_values(stream::IO, elen, prop::ArrayProperty)
    write(stream, prop.data)
end
function read_binary_values!(stream::IO, elen, prop::ArrayProperty)
    read!(stream, prop.data)
end

# Optimization: For properties with homogeneous type, shuffle into a buffer
# matrix before a batch-wise call to write().  This is a big speed improvement
# for elements constructed of simple arrays with homogenous type -
# serialization speed generally seems to be limited by the many individual
# calls to write() with small buffers.
function write_binary_values(stream::IO, elen, props::ArrayProperty{T}...) where {T}
    batchsize = 100
    numprops = length(props)
    buf = Matrix{T}(numprops, batchsize)
    for i=1:batchsize:elen
        thisbatchsize = min(batchsize, elen-i+1)
        for j=1:numprops
            buf[j,1:thisbatchsize] = props[j].data[i:i+thisbatchsize-1]
        end
        unsafe_write(stream, pointer(buf), sizeof(T)*numprops*thisbatchsize)
    end
end


#-------------------------------------------------------------------------------
# High level IO for complete files

"""
    load_ply(file)

Load data from a ply file and return a `Ply` datastructure.  `file` may either
be a file name or an open stream.
"""
function load_ply(io::IO)
    elements, format, comments = read_header(io)
    if format != Format_ascii
        if _host_is_little_endian && format != Format_binary_little
            error("Reading big endian ply on little endian host is not implemented")
        elseif !_host_is_little_endian && format != Format_binary_big
            error("Reading little endian ply on big endian host is not implemented")
        end
    end
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


"""
    save_ply(ply::Ply, file; [ascii=false])

Save data from `Ply` data structure into `file` which may be a filename or an
open stream.  The file will be native endian binary, unless the keyword
argument `ascii` is set to `true`.
"""
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
