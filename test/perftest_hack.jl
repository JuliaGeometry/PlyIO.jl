# Very junky script testing performance against direct binary IO
#
# In this test, it's about 5x slower to write to ply than to directly dump the
# bytes, this seems to be due to the many calls to write()

using BufferedStreams

import PlyIO: save_ply, write_header, Ply, Element, ArrayProperty, ListProperty


ply = Ply()

nverts = 100000

vertex = Element("vertex",
                 ArrayProperty("x", randn(nverts)),
                 ArrayProperty("y", randn(nverts)),
                 ArrayProperty("z", randn(nverts)),
                 ArrayProperty("r", rand(nverts)),
                 ArrayProperty("g", rand(nverts)),
                 ArrayProperty("b", rand(nverts)))
push!(ply, vertex)

# Some triangular faces
vertex_index = ListProperty("vertex_index", Int32, Int32)
for i=1:nverts
   push!(vertex_index, rand(0:nverts-1,3))
end
push!(ply, Element("face", vertex_index))

#=
# Some edges
vertex_index = ListProperty("vertex_index", Int32, Int32)
for i=1:nverts
   push!(vertex_index, rand(0:nverts-1,2))
end
push!(ply, Element("edge", vertex_index))
=#

function save_ply_ref(ply, stream::IO)
    write_header(ply, stream, false)
    x = ply["vertex"]["x"].data::Vector{Float64}
    y = ply["vertex"]["y"].data::Vector{Float64}
    z = ply["vertex"]["z"].data::Vector{Float64}
    r = ply["vertex"]["r"].data::Vector{Float64}
    g = ply["vertex"]["g"].data::Vector{Float64}
    b = ply["vertex"]["b"].data::Vector{Float64}

    vertex_index = ply["face"]["vertex_index"]
    viinds = vertex_index.start_inds::Vector{Int32}
    vidata = vertex_index.data::Vector{Int32}

    #=
    for i=1:length(x)
        write(stream, x[i])
        write(stream, y[i])
        write(stream, z[i])
        write(stream, r[i])
        write(stream, g[i])
        write(stream, b[i])
    end

    for i=1:length(viinds)-1
        len = viinds[i+1] - viinds[i]
        write(stream, len)
        write(stream, vidata[viinds[i]:viinds[i+1]-1])
    end
    =#

    # Buffered reordering
    #=
    write(stream, [x y z r g b]')
    write(stream, viinds)
    write(stream, vidata)
    =#

    # Benchmark against direct binary IO (invalid ply!), which should be about
    # as fast as you can hope for.
    write(stream, x)
    write(stream, y)
    write(stream, z)
    write(stream, r)
    write(stream, g)
    write(stream, b)

    write(stream, viinds)
    write(stream, vidata)

end

function save_ply_ref(ply, filename::AbstractString)
    open(filename, "w") do fid
        save_ply_ref(ply, fid)
    end
end

function save_ply_buffered(ply, filename; kwargs...)
    open(filename, "w") do fid
        save_ply(ply, BufferedOutputStream(fid, 2^16); kwargs...)
    end
end

save_ply(ply, "test.ply", ascii=false)
save_ply_buffered(ply, "test.ply", ascii=false)

save_ply_ref(ply, "test2.ply")

Profile.clear_malloc_data()
@time save_ply(ply, "test.ply", ascii=false)
@time save_ply_buffered(ply, "test.ply", ascii=false)

@time save_ply_ref(ply, "test2.ply")

#run(`displaz -script test.ply`)
