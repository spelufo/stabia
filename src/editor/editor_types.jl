mutable struct Perp
  p :: Vec3f
  θ :: Float32 # relative to the x axis
end

Perp(p::Vec3f, p2::Vec3f) = begin
  v = normalize(Vec3f(p2[1], p2[2], p[3]) - p)
  Perp(p, angle(Ex, v))
end


mutable struct Perps
  perps :: Vector{Perp}
  meshes :: Vector{GLMesh}
  add_start :: Union{Vec3f, Nothing}
  add_mesh :: Union{GLMesh, Nothing}
  active :: Int
end

Perps() =
  Perps(
    Perp[],
    GLMesh[],
    nothing,
    nothing,
    0,
  )


mutable struct Cell
  j :: Ints3
  p :: Vec3f   # Position, the point with minimum coordinates.
  L :: Float32 # Length of the side of the cell in mm.
  V :: Array{N0f16,3}
  N :: Union{Array{Vec3f,3}, Nothing}
  holes :: Union{Vector{GLMesh}, Nothing}
  texture :: UInt32
  N_texture :: UInt32
end

Cell(scan::HerculaneumScan, j::Ints3) = begin
  p0, p1 = cell_range_mm(scan, j...)
  L = p1[1] - p0[1]
  V = load_cell(scan, j...)
  N = nothing
  if have_cell_normals_relaxed(scan, j...)
    N4, _ = load_cell_normals_relaxed(scan, j...)
    N = reinterpret(reshape, Vec3f, N4)
  end
  holes = nothing
  # if have_cell_holes(scan, j...)
  #   holes = [GLMesh(m; scale=L/500f0) for m in load_cell_holes(scan, j...)]
  # end
  Cell(j, p0, L, V, N, holes, UInt32(0), UInt32(0))
end


mutable struct Document
  scan :: HerculaneumScan
  cells :: Vector{Cell}
end

# Called by main(), for things that need to be reset when a new window/editor is
# created. It is an escape hatch, we should only need it if keeping transient
# state under Document, which should be shunned in favor os putting it in Editor.
reload!(doc::Document) = begin
  nothing
end


mutable struct Viewport
  name :: String
  pos :: ImVec2
  size :: ImVec2
  visible :: Bool
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
  click_start :: Union{ImVec2, Nothing}
end

Viewport(name::String, camera::Camera) =
  Viewport(name, ImVec2(0, 0), ImVec2(0, 0), true, Framebuffer(),
    Shader("shader.glsl"), camera, false, nothing)


mutable struct Editor
  doc :: Document
  scan :: HerculaneumScan
  cell :: Cell

  cursor :: Pose
  frame :: Int
  view_3d    :: Union{Viewport, Nothing}
  view_top   :: Union{Viewport, Nothing}
  view_cross :: Union{Viewport, Nothing}

  style :: Int32
  draw_axis_xy :: Ref{Bool}
  draw_axis_yz :: Ref{Bool}
  draw_axis_zx :: Ref{Bool}
  draw_holes :: Ref{Bool}

  perps :: Perps

  # sheet sim
  sheet
  sheet_update! :: Union{Function, Nothing}
  δ :: Ref{Float32}
  k_s :: Ref{Float32}
  k_n :: Ref{Float32}
  equipot_running :: Bool
end

Editor(doc::Document) = begin
  cell = doc.cells[1]
  load_textures(cell)
  ed = Editor(
    doc,
    doc.scan,
    cell,
    Pose(center(cell)), # cursor
    0, # frame
    nothing, nothing, nothing, # views
    Int32(1), # style
    Ref(true), Ref(false), Ref(false), # draw_axis_*
    Ref(false), # draw_holes
    Perps(),
    # sheet sim
    nothing, # sheet
    nothing, # sheet_update!
    Ref(cell.L/500f0), # δ
    Ref(1f0), # k_s
    Ref(1f0), # k_n
    false,
  )
  reset_views!(ed)
  ed
end


