__precompile__()

module PlyIO

using Compat

# Types for the ply data model
export Ply, PlyElement, PlyComment, ArrayProperty, ListProperty
export plyname  # Is there something in base we could overload for this?

# High level file IO
# (TODO: FileIO?)
export load_ply, save_ply

include("types.jl")
include("io.jl")

end
