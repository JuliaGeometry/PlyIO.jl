using PlyIO
using StaticArrays
using Test

@testset "PlyIO" begin

@testset "types" begin
    ply = Ply()
    push!(ply, PlyComment("PlyComment"))
    elt = PlyElement("A", ArrayProperty("x", UInt8[1,2,3]),
                          ArrayProperty("y", Float32[1.1,2.2,3.3]))
    push!(ply, elt)
    @test sprint(show, ply) == """
          Ply with header:
           ply
           format ascii 1.0
           comment PlyComment
           element A 3
           property uint8 x
           property float32 y
           end_header"""
    @test sprint(show, elt) == "PlyElement \"A\" of length 3 with properties [\"x\", \"y\"]"
end

@testset "simple" begin
    ply = Ply()
    push!(ply, PlyComment("PlyComment about A"))

    push!(ply, PlyElement("A",
                          ArrayProperty("x", UInt8[1,2,3]),
                          ArrayProperty("y", Float32[1.1,2.2,3.3]),
                          ListProperty("a_list", Vector{Int64}[[0,1], [2,3,4], [5]])))
    push!(ply, PlyComment("PlyComment about B"))
    push!(ply, PlyComment("PlyObjInfo", obj_info=true))
    push!(ply, PlyComment("PlyComment about B 2"))
    push!(ply, PlyElement("B",
                          ArrayProperty("r", Int16[-1,1]),
                          ArrayProperty("g", Int16[1,1])))
    push!(ply, PlyComment("Final comment"))

    buf = IOBuffer()
    save_ply(ply, buf, ascii=true)
    str = String(take!(buf))
    open("simple_test_tmp.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    comment PlyComment about A
    element A 3
    property uint8 x
    property float32 y
    property list int32 int64 a_list
    comment PlyComment about B
    obj_info PlyObjInfo
    comment PlyComment about B 2
    element B 2
    property int16 r
    property int16 g
    comment Final comment
    end_header
    1 1.1 2 0 1
    2 2.2 3 2 3 4
    3 3.3 1 5
    -1 1
    1 1
    """
end

@testset "empty elements" begin
    ply = Ply()

    push!(ply, PlyElement("A", ArrayProperty("x", UInt8[])))
    push!(ply, PlyElement("B", ListProperty("a_list", Vector{Int64}[[], [], []])))

    buf = IOBuffer()
    save_ply(ply, buf, ascii=true)
    str = String(take!(buf))
    open("empty_test_tmp.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    element A 0
    property uint8 x
    element B 3
    property list int32 int64 a_list
    end_header
    0 
    0 
    0 
    """
end

@testset "roundtrip" begin
    @testset "ascii=$test_ascii" for test_ascii in [false, true]
        ply = Ply()

        push!(ply, PlyComment("A comment"))
        push!(ply, PlyComment("Blah blah"))
        push!(ply, PlyComment("x=10", obj_info=true))

        nverts = 10

        x = collect(Float64, 1:nverts)
        y = collect(Int16, 1:nverts)
        push!(ply, PlyElement("vertex", ArrayProperty("x", x),
                                        ArrayProperty("y", y)))

        # Some triangular faces
        vertex_index = ListProperty("vertex_index", Int32, Int32)
        for i=1:nverts
            push!(vertex_index, rand(0:nverts-1,3))
        end
        push!(ply, PlyElement("face", vertex_index))

        save_ply(ply, "roundtrip_test_tmp.ply", ascii=test_ascii)

        newply = load_ply("roundtrip_test_tmp.ply")

        # TODO: Need a better way to access the data arrays than this.
        @test newply["vertex"]["x"] == x
        @test newply["vertex"]["y"] == y
        @test newply["face"]["vertex_index"] == vertex_index

        @test newply.comments == [PlyComment("A comment",false,1),
                                  PlyComment("Blah blah",false,1),
                                  PlyComment("x=10",true,1)]
    end

    @testset "proptype=$proptype" for proptype in [Int8, Int16, Int32, Int64,
                                                   UInt8, UInt16, UInt32, UInt64,
                                                   Float32, Float64]
        ply = Ply()
        arrayprop = fill(proptype(42), 1)
        listprop = ListProperty("listprop", proptype<:Integer ? proptype : Int32, proptype)
        push!(listprop, collect(proptype, 1:10))
        push!(ply, PlyElement("test", ArrayProperty("arrayprop", arrayprop), listprop))
        io = IOBuffer()
        save_ply(ply, io)
        seek(io, 0)
        newply = load_ply(io)
        @test length(newply) == 1
        @test typeof(newply["test"]["arrayprop"][1]) == proptype
        @test newply["test"]["arrayprop"] == arrayprop
        @test typeof(newply["test"]["listprop"][1]) == Vector{proptype}
        @test newply["test"]["listprop"] == listprop
    end

    @testset "Batched writes for homogenous properties" begin
        ply = Ply()
        nverts = 1000
        x, y, z = [rand(nverts) for _ = 1:3]
        push!(ply, PlyElement("vertex",
                              ArrayProperty("x", x),
                              ArrayProperty("y", y),
                              ArrayProperty("z", z)))
        io = IOBuffer()
        save_ply(ply, io)
        seek(io, 0)
        newply = load_ply(io)
        @test length(newply) == 1
        @test newply["vertex"]["x"] == x
        @test newply["vertex"]["y"] == y
        @test newply["vertex"]["z"] == z
    end
end


@testset "SVector properties" begin
    ply = Ply()
    push!(ply, PlyElement("A",
                          ArrayProperty(["x","y"], SVector{2,Float64}[SVector(1,2), SVector(3,4)])
                         ))
    push!(ply, PlyElement("B",
                          ArrayProperty(["r","g","b"], SVector{3,UInt8}[SVector(1,2,3)])
                         ))
    buf = IOBuffer()
    save_ply(ply, buf, ascii=true)
    str = String(take!(buf))
    open("SVector_properties_test_tmp.ply", "w") do fid
        write(fid, str)
    end
    @test str ==
    """
    ply
    format ascii 1.0
    element A 2
    property float64 x
    property float64 y
    element B 1
    property uint8 r
    property uint8 g
    property uint8 b
    end_header
    1.0 2.0
    3.0 4.0
    1 2 3
    """
end


@testset "Malformed ply headers" begin
    @test_throws ErrorException load_ply(IOBuffer("asdf"))

    @test_throws ErrorException load_ply(IOBuffer("ply"))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 2.0
                                                  """))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format 1.0
                                                  end_header"""))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 1.0
                                                  asdf
                                                  end_header"""))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 1.0
                                                  element el
                                                  end_header"""))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 1.0
                                                  property float x
                                                  end_header"""))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 1.0
                                                  element el 0
                                                  property
                                                  end_header"""))

    @test_throws ErrorException load_ply(IOBuffer("""
                                                  ply
                                                  format ascii 1.0
                                                  element el 0
                                                  property list
                                                  end_header"""))
end

end # @testset PlyIO
