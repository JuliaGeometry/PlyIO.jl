__precompile__()

module PlyIO

# Types for the ply data model
export Ply, Element, Comment, PlyProperty, ArrayProperty, ListProperty

# High level file IO
# (TODO: FileIO?)
export load_ply, save_ply

include("types.jl")
include("io.jl")

end
