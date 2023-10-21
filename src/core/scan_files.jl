const scroll_1_54 = HerculaneumScan("full-scrolls/Scroll1.volpkg", "20230205180739", 7.91f0, 54f0, 8096, 7888, 14376)
const scroll_2_54 = HerculaneumScan("full-scrolls/Scroll2.volpkg", "20230210143520", 7.91f0, 54f0, 11984, 10112, 14428)
const scroll_2_88 = HerculaneumScan("full-scrolls/Scroll2.volpkg", "20230212125146", 7.91f0, 88f0, 11136, 8480, 1610)
const fragment_1_54 = HerculaneumScan("fragments/Frag1.volpkg", "20230205142449", 3.24f0, 54f0, 7198, 1399, 7219)
const fragment_1_88 = HerculaneumScan("fragments/Frag1.volpkg", "20230213100222", 3.24f0, 88f0, 7332, 1608, 7229)
const fragment_2_54 = HerculaneumScan("fragments/Frag2.volpkg", "20230216174557", 3.24f0, 54f0, 9984, 2288, 14111)
const fragment_2_88 = HerculaneumScan("fragments/Frag2.volpkg", "20230226143835", 3.24f0, 88f0, 10035, 2112, 14144)
const fragment_3_54 = HerculaneumScan("fragments/Frag3.volpkg", "20230215142309", 3.24f0, 54f0, 6312, 1440, 6656)
const fragment_3_88 = HerculaneumScan("fragments/Frag3.volpkg", "20230212182547", 3.24f0, 88f0, 6108, 1644, 6650)


# Server paths #################################################################

@inline scan_slice_filename(scan::HerculaneumScan, iz::Int; ext=".tif") = begin
  ndigits = ceil(Int, log10(scan.slices))
  zpad((iz - 1), ndigits) * ext
end

scan_slice_server_path(scan::HerculaneumScan, iz::Int) =
  "$(scan.volpkg_path)/volumes/$(scan.id)/$(scan_slice_filename(scan, iz))"

@inline cell_name(jy::Int, jx::Int, jz::Int) =
  "cell_yxz_$(zpad(jy, 3))_$(zpad(jx, 3))_$(zpad(jz, 3))"

@inline grid_cell_filename(jy::Int, jx::Int, jz::Int) =
  cell_name(jy, jx, jz) * ".tif"

@inline grid_cell_h5_filename(jy::Int, jx::Int, jz::Int) =
  cell_name(jy, jx, jz) * ".h5"

grid_cell_server_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  "$(scan.volpkg_path)/volume_grids/$(scan.id)/$(grid_cell_filename(jy, jx, jz))"

grid_cell_h5_server_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  "$(scan.volpkg_path)/volume_grids_h5/$(scan.id)/$(grid_cell_h5_filename(jy, jx, jz))"

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

scan_slice_path(scan::HerculaneumScan, iz::Int)::String =
  joinpath(DATA_DIR, scan_slice_server_path(scan, iz))

have_slice(scan::HerculaneumScan, iz::Int) =
  isfile(scan_slice_path(scan, iz))

load_slice(scan::HerculaneumScan, iz::Int) =
  load(scan_slice_path(scan, iz))

grid_cell_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  joinpath(DATA_DIR, grid_cell_server_path(scan, jy, jx, jz))

have_grid_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(grid_cell_path(scan, jy, jx, jz))

load_grid_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(grid_cell_path(scan, jy, jx, jz))

grid_cell_h5_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  joinpath(DATA_DIR, grid_cell_h5_server_path(scan, jy, jx, jz))

small_volume_path(scan::HerculaneumScan) =
  joinpath(DATA_DIR, small_volume_server_path(scan))

have_small_volume(scan::HerculaneumScan) =
  isfile(small_volume_path(scan))

load_small_volume(scan::HerculaneumScan) =
  load(small_volume_path(scan))

segment_path(scan::HerculaneumScan, segment_id::AbstractString) =
  joinpath(DATA_DIR, segment_server_path(scan, segment_id))

have_segment(scan::HerculaneumScan, segment_id::AbstractString) =
  isdir(segment_path(scan, segment_id))

load_segment_mesh(scan::HerculaneumScan, segment_id::AbstractString) =
  load(joinpath(segment_path(scan, segment_id), "$segment_id.obj"))

missing_cells(q_cells) = begin
  cells = []
  for (jy, jx, jz) = q_cells
    if !have_grid_cell(scroll_1_54, jy, jx, jz)
      push!(cells, (jy, jx, jz))
    end
  end
  cells
end

mesh_grid_cells_missing(mesh) =
  missing_cells(mesh_grid_cells(mesh))


# Segmentation files

segmentation_dir(scan::HerculaneumScan) =
  joinpath(DATA_DIR, scan.volpkg_path, "segmentation")

cell_segmentation_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(segmentation_dir(scan), cell_name(jy, jx, jz))

cell_probabilities_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  joinpath(cell_segmentation_dir(scan, jy, jx, jz), "$(cell_name(jy, jx, jz))_probabilities.h5")


load_cell_probabilities(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  fid = h5open(cell_probabilities_path(scan, jy, jx, jz))
  P = permutedims(read(fid, "exported_data")[1,:,:,:,1], (2, 1, 3))
  close(fid)
  P
end

