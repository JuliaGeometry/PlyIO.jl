# Ply polygon file IO

**PlyIO** is a package for reading and writing data in the Ply polygon file
format (also called the Stanford triangle format).

## Quick start

For now, here's an example of how to write a basic ply file containing random
triangles and edges.

```julia
import PlyIO: write_ply_model, Ply, Element, ArrayProperty, ListProperty

ply = Ply()

nverts = 1000

# Random vertices with position and color
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

# Some edges
vertex_index = ListProperty("vertex_index", Int32, Int32)
for i=1:nverts
   push!(vertex_index, rand(0:nverts-1,2))
end
push!(ply, Element("edge", vertex_index))

write_ply_model(ply, "test.ply", ascii=true)
```

## The file format

In the abstract, the ply format is a container for a set of named tables of
numeric data.  Each table, or **element**, has several named columns or
**properties**.  Properties can be either simple numeric values (floating point
or signed/unsigned integers), or variable length lists of such numeric values.

For geometric data, there are some loose
[naming conventions](http://paulbourke.net/dataformats/ply/).  Unfortunately
there's no official standard.
