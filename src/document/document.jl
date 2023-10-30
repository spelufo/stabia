# Document Objects #############################################################

abstract type DocumentObject end

include("cell.jl")
include("perps.jl")
include("sheet.jl")
include("mesh.jl")


# Document #####################################################################

mutable struct Document
  scan :: HerculaneumScan
  cells :: Vector{Cell}
  objects :: Vector{DocumentObject}
end

# Called by main(), for things that need to be reset when a new window/editor is
# created. It is an escape hatch, we should only need it if keeping transient
# state under Document, which should be shunned in favor os putting it in Editor.
reload!(doc::Document) = begin
  nothing
end
