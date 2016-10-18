using PlyIO
using StaticArrays
using Base.Test

using PlyIO.Ply

@testset "simple" begin
    ply = Ply.Data()
    push!(ply, Comment("Comment about A"))

    push!(ply, Element("A",
                          ArrayProp("x", UInt8[1,2,3]),
                          ArrayProp("y", Float32[1.1,2.2,3.3]),
                          ListProp("a_list", [[0,1], [2,3,4], [5]])))
    push!(ply, Comment("Comment about B"))
    push!(ply, Comment("Comment about B 2"))
    push!(ply, Element("B",
                          ArrayProp("r", Int16[-1,1]),
                          ArrayProp("g", Int16[1,1])))
    push!(ply, Comment("Final comment"))

    buf = IOBuffer()
    save_ply(ply, buf, ascii=true, )
    str = takebuf_string(buf)
    open("simple_test_tmp.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    comment Comment about A
    element A 3
    property uchar x
    property float y
    property list int int64 a_list
    comment Comment about B
    comment Comment about B 2
    element B 2
    property short r
    property short g
    comment Final comment
    end_header
    1	1.1	2 0 1
    2	2.2	3 2 3 4
    3	3.3	1 5
    -1	1
    1	1
    """
end


@testset "roundtrip" begin
    @testset "ascii=$test_ascii" for test_ascii in [false, true]
        ply = Ply.Data()

        push!(ply, Comment("A comment"))
        push!(ply, Comment("Blah blah"))

        nverts = 10

        x = collect(Float64, 1:nverts)
        y = collect(Int16, 1:nverts)
        push!(ply, Element("vertex", ArrayProp("x", x),
                                        ArrayProp("y", y)))

        # Some triangular faces
        vertex_index = ListProp("vertex_index", Int32, Int32)
        for i=1:nverts
            push!(vertex_index, rand(0:nverts-1,3))
        end
        push!(ply, Element("face", vertex_index))

        save_ply(ply, "roundtrip_test_tmp.ply", ascii=test_ascii)

        newply = load_ply("roundtrip_test_tmp.ply")

        # TODO: Need a better way to access the data arrays than this.
        @test newply["vertex"]["x"].data == x
        @test newply["vertex"]["y"].data == y
        @test newply["face"]["vertex_index"].start_inds == vertex_index.start_inds
        @test newply["face"]["vertex_index"].data == vertex_index.data

        @test newply.comments == [Comment("A comment",1), Comment("Blah blah",1)]
    end
end


@testset "SVector properties" begin
    ply = Ply.Data()
    push!(ply, Element("A",
                       ArrayProp(["x","y"], SVector{2,Float64}[SVector(1,2), SVector(3,4)])
                      ))
    push!(ply, Element("B",
                       ArrayProp(["r","g","b"], SVector{3,UInt8}[SVector(1,2,3)])
                      ))
    buf = IOBuffer()
    save_ply(ply, buf, ascii=true)
    str = takebuf_string(buf)
    open("SVector_properties_test_tmp.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    element A 2
    property double x
    property double y
    element B 1
    property uchar r
    property uchar g
    property uchar b
    end_header
    1.0	2.0
    3.0	4.0
    1	2	3
    """
end

