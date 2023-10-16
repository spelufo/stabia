using FileIO, MeshIO





segment_grid_cells(mesh) = begin
  
end

segment_grid_cells(path::String) =
  load_segment(load(path))
