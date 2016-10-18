__precompile__()

module PlyIO

include("types.jl")

using .Ply
import .Ply: PropNameList

# Types for the ply data model
export PlyData, Ply

# High level file IO
# (TODO: FileIO?)
export load_ply, save_ply

include("io.jl")

end
