# Server paths #################################################################

@inline scan_slice_filename(scan::HerculaneumScan, iz::Int; ext=".tif") = begin
  ndigits = ceil(Int, log10(scan.slices))
  zpad((iz - 1), ndigits) * ext
end

scan_slice_server_path(scan::HerculaneumScan, iz::Int) =
  "$(scan.volpkg_path)/volumes/$(scan.id)/$(scan_slice_filename(scan, iz))"

@inline cell_name(jy::Int, jx::Int, jz::Int) =
  "cell_yxz_$(zpad(jy, 3))_$(zpad(jx, 3))_$(zpad(jz, 3))"

@inline cell_filename(jy::Int, jx::Int, jz::Int) =
  cell_name(jy, jx, jz) * ".tif"

@inline cell_h5_filename(jy::Int, jx::Int, jz::Int) =
  cell_name(jy, jx, jz) * ".h5"

cell_server_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  "$(scan.volpkg_path)/volume_grids/$(scan.id)/$(cell_filename(jy, jx, jz))"

cell_h5_server_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  "$(scan.volpkg_path)/volume_grids_h5/$(scan.id)/$(cell_h5_filename(jy, jx, jz))"

small_volume_server_path(scan::HerculaneumScan) =
  "$(scan.volpkg_path)/volumes_small/$(scan.id)_small.tif"

segments_server_path(scan::HerculaneumScan; hari=false) =
  if !hari
    "$(scan.volpkg_path)/paths"
  else
    "hari-seldon-uploads/team-finished-paths/scroll1"
  end

segment_server_path(scan::HerculaneumScan, segment_id::AbstractString; hari=false) =
  segments_server_path(scan::HerculaneumScan; hari=hari) * "/" * segment_id


# Local files ##################################################################

const DATA_DIR = normpath(get(ENV, "VESUVIUS_DATA_DIR", joinpath(dirname(dirname(@__DIR__)), "data")))

# Slices

scan_slice_path(scan::HerculaneumScan, iz::Int)::String =
  joinpath(DATA_DIR, scan_slice_server_path(scan, iz))

have_slice(scan::HerculaneumScan, iz::Int) =
  isfile(scan_slice_path(scan, iz))

load_slice(scan::HerculaneumScan, iz::Int) =
  load(scan_slice_path(scan, iz))

# Cells

cell_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  joinpath(DATA_DIR, cell_server_path(scan, jy, jx, jz))

have_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(cell_path(scan, jy, jx, jz))

load_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(cell_path(scan, jy, jx, jz))

cell_h5_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  joinpath(DATA_DIR, cell_h5_server_path(scan, jy, jx, jz))

missing_cells(q_cells) = begin
  cells = []
  for (jy, jx, jz) = q_cells
    if !have_cell(scroll_1_54, jy, jx, jz)
      push!(cells, (jy, jx, jz))
    end
  end
  cells
end

mesh_cells_missing(mesh) =
  missing_cells(mesh_cells(mesh))

# Small

small_volume_path(scan::HerculaneumScan) =
  joinpath(DATA_DIR, small_volume_server_path(scan))

have_small_volume(scan::HerculaneumScan) =
  isfile(small_volume_path(scan))

load_small_volume(scan::HerculaneumScan) =
  load(small_volume_path(scan))

# Segments

segment_path(scan::HerculaneumScan, segment_id::AbstractString) =
  joinpath(DATA_DIR, segment_server_path(scan, segment_id))

have_segment(scan::HerculaneumScan, segment_id::AbstractString) =
  isdir(segment_path(scan, segment_id))

load_segment_mesh(scan::HerculaneumScan, segment_id::AbstractString) =
  load(joinpath(segment_path(scan, segment_id), "$segment_id.obj"))
