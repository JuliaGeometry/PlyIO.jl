using PlyIO
using Base.Test

import PlyIO: load_ply, save_ply, Ply, Element, ArrayProperty, ListProperty

@testset "roundtrip" begin
    @testset "ascii=$test_ascii" for test_ascii in [true, false]
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
