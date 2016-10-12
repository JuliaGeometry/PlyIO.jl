# Ply polygon file IO

**PlyIO** is a package for reading and writing data in the
[Ply](http://paulbourke.net/dataformats/ply/) polygon file format, also called
the Stanford triangle format.

## Quick start

Here's an example of how to write a basic ply file containing random triangles
and edges:

```julia
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
save_ply(ply, "test.ply", ascii=true)
```

Opening this file using a program like
[displaz](https://github.com/c42f/displaz), for example using `displaz test.ply`,
you should see something like

![Example one](doc/example1.png)

## The file format

In the abstract, the ply format is a container for a set of named tables of
numeric data.  Each table, or **element**, has several named columns or
**properties**.  Properties can be either simple numeric values (floating point
or signed/unsigned integers), or variable length lists of such numeric values.

For geometric data, there are some loose
[naming conventions](http://paulbourke.net/dataformats/ply/).  Unfortunately
there's no official standard.
