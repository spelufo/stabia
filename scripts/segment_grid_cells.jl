using FileIO, MeshIO

include("../src/data/data.jl")


mesh_grid_cells(mesh) = begin
  cells = Set()
  for v = mesh.position
    jy, jx, jz = Int.(div.(v, 500))
    push!(cells, (jy, jx, jz))
  end
  cells
end

mesh_grid_cells_missing(mesh) = begin
  mesh_cells = mesh_grid_cells(mesh)
  # collect the ones missing, for smoother Threads.@threads run.
  cells = []
  for (jy, jx, jz) = mesh_cells
    if !have_grid_cell(scroll_1_54, jy, jx, jz)
      push!(cells, (jy, jx, jz))
    end
  end
  cells
end

download_mesh_grid_cells(segment_id) = begin
  mesh = load_segment_mesh(scroll_1_54, segment_id)
  cells = mesh_grid_cells_missing(mesh)
  download_grid_cells(scroll_1_54, cells)
end
