using PlyIO
using Base.Test

import PlyIO: load_ply, save_ply, Ply, Element, ArrayProperty, ListProperty

@testset "simple" begin
    ply = Ply()

    push!(ply, Element("A",
                       ArrayProperty("x", UInt8[1,2,3]),
                       ListProperty("y", [[0,1], [2,3,4], [5]])))
    push!(ply, Element("B",
                       ArrayProperty("y", Int16[-1,1])))

    buf = IOBuffer()
    save_ply(ply, buf, ascii=true)
    str = takebuf_string(buf)
    open("foo.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    element A 3
    property uchar x
    property list int int64 y
    element B 2
    property short y
    end_header
    1 2 0 1  
    2 3 2 3 4  
    3 1 5  
    -1 
    1 
    """
end

@testset "roundtrip" begin
    @testset "ascii=$test_ascii" for test_ascii in [false, true]
        ply = Ply()

        nverts = 10

        x = collect(Float64, 1:nverts)
        y = collect(Int16, 1:nverts)
        push!(ply, Element("vertex", ArrayProperty("x", x),
                                     ArrayProperty("y", y)))

        # Some triangular faces
        vertex_index = ListProperty("vertex_index", Int32, Int32)
        for i=1:nverts
            push!(vertex_index, rand(0:nverts-1,3))
        end
        push!(ply, Element("face", vertex_index))

        save_ply(ply, "roundtrip_test.ply", ascii=test_ascii)

        newply = load_ply("roundtrip_test.ply")

        # TODO: Need a better way to access the data arrays than this.
        @test newply["vertex"]["x"].data == x
        @test newply["vertex"]["y"].data == y
        @test newply["face"]["vertex_index"].start_inds == vertex_index.start_inds
        @test newply["face"]["vertex_index"].data == vertex_index.data
    end
end
