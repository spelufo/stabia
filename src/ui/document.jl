abstract type DocumentObject end


# Scan data ####################################################################

mutable struct Cell <: DocumentObject
  j :: Ints3
  p :: Vec3f   # Position, the point with minimum coordinates.
  L :: Float32 # Length of the side of the cell in mm.
  V :: Array{N0f16,3}
  N :: Union{Array{Vec3f,3}, Nothing}
  texture :: UInt32
  N_texture :: UInt32
end

Cell(scan::HerculaneumScan, j::Ints3) = begin
  p0, p1 = cell_range_mm(scan, j...)
  L = p1[1] - p0[1]
  V = load_cell(scan, j...)
  N = nothing
  if have_cell_normals(scan, j...)
    N, _ = load_cell_normals(scan, j...)
  end
  Cell(j, p0, L, V, N, UInt32(0), UInt32(0))
end

center(cell::Cell) =
  cell.p + cell.L * E1 / 2f0

################################################################################

# TODO: Should the draw calls of these DocumentObjects live here? Adopt some order.

mutable struct StaticMesh <: DocumentObject
  pose :: Pose
  mesh :: GLMesh
end

StaticBoxMesh(p0::Vec3f, p1::Vec3f) =
  StaticMesh(Pose(p0), GLBoxMesh(zero(Vec3f), p1 - p0))
  # StaticMesh(Pose(E0), GLBoxMesh(p0, p1))

StaticQuadMesh(p::Vec3f, n::Vec3f, v::Vec3f, w::Float32, h::Float32) = begin
  h /= 2f0
  w /= 2f0
  u = cross(n, v)
  p1 = - w*u - h*v
  p2 = + w*u - h*v
  p3 = + w*u + h*v
  p4 = - w*u + h*v
  StaticMesh(Pose(p), GLQuadMesh(p1, p2, p3, p4))
end

draw(mesh::StaticMesh, shader::Shader) = begin
  M = model_matrix(mesh.pose)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(mesh.mesh)
end

draw(cc::Plane, shader::Shader) = begin
  h = cell_mm(the_editor.scan) / 2f0
  l =  h * sqrt(2f0)
  u = Ez
  v = cross(u, cc.n)
  mesh = GLQuadMesh(
    cc.p - l*v - h*u,
    cc.p + l*v - h*u,
    cc.p + l*v + h*u,
    cc.p - l*v + h*u,
  )
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(mesh)
end

draw(gs::GridSheet, shader::Shader) = begin
  M = scaling(1f0)
  glUniformMatrix4fv(glGetUniformLocation(shader, "model"), 1, GL_FALSE, M)
  draw(GLGridMesh(gs))
end


# Document ########################################################################

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
