# 1. Compute ϕ from rough_mesh.
# 2. Average ϕ over hole sheets and round to the nearest integer.
# 3. Compute ϕ from hole sheets.
# 4. Segment with marching squares.

f() = begin
  mesh = load_segment_mesh(scan, segment_id)

  P = load_cell_probabilities(scan, jy, jx, jz)
  S = zeros(Float32, CELL_SIZE, CELL_SIZE, CELL_SIZE)
  rasterize_mesh!(S, mesh, 20f0, jy, jx, jz)
  ϕ = copy(S)
  relax_potential!(ϕ, S, P)

  for sheet_face = ...
  end

  ...
end
