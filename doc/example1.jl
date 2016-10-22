using PlyIO

ply = Ply()
push!(ply, PlyComment("An example ply file"))

nverts = 1000

# Random vertices with position and color
vertex = PlyElement("vertex",
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
push!(ply, PlyElement("face", vertex_index))

# Some edges
vertex_index = ListProperty("vertex_index", Int32, Int32)
for i=1:nverts
   push!(vertex_index, rand(0:nverts-1,2))
end
push!(ply, PlyElement("edge", vertex_index))

# For the sake of the example, ascii format is used, the default binary mode is faster.
save_ply(ply, "example1.ply", ascii=true)
