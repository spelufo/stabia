const CELL_SIZE = 500
const SMALLER_BY = 10

struct HerculaneumScan
  volpkg_path :: String
  id :: String
  resolution_um :: Float32
  xray_energy_KeV :: Float32
  width::Int
  height::Int
  slices::Int
end

scan_from_meta(meta_path, volpkg_path) = begin
  meta = JSON.parsefile(meta_path)
  energy = parse(Float32, match(r"(\d+)\s*KeV"i, meta["name"])[1])
  HerculaneumScan(volpkg_path, meta["uuid"], meta["voxelsize"], energy, meta["width"], meta["height"], meta["slices"])
end

scan_from_volpkg(volpkg_path, id) = begin
  meta_path = joinpath(DATA_DIR, volpkg_path, "volumes", id, "meta.json")
  scan_from_meta(meta_path, volpkg_path)
end

const Ints1 = NTuple{1, Int}
const Ints2 = NTuple{2, Int}
const Ints3 = NTuple{3, Int}

scroll_core_mm(scan::HerculaneumScan) = begin
  core = nothing
  if     scan == scroll_1_54    core = scroll_1_54_core_mm
  elseif scan == scroll_2_54    core = scroll_2_54_core_mm
  elseif scan == pherc_1667_88  core = pherc_1667_88_core_mm
  end
  core
end

scan_mask(scan::HerculaneumScan) = begin
  mask = nothing
  if     scan == scroll_1_54    mask = scroll_1_54_mask
  elseif scan == pherc_1667_88  mask = pherc_1667_88_mask
  elseif scan == pherc_0332_53  mask = pherc_0332_53_mask
  end
  mask
end

layer_cells(scan::HerculaneumScan, jz::Int) =
  map(Tuple, filter(c -> c[3] == jz, eachrow(scan_mask(scan))))


# Measures

@inline px_mm(scan::HerculaneumScan) =
  scan.resolution_um / 1000f0

scan_dimensions_mm(scan::HerculaneumScan) =
  px_mm(scan) * Vec3f(scan.width, scan.height, scan.slices)

scan_position_mm(scan::HerculaneumScan, iy::Real, ix::Real, iz::Real) =
  px_mm(scan) * Vec3f(ix-1, iy-1, iz-1)

@inline cell_mm(scan::HerculaneumScan) =
  CELL_SIZE * px_mm(scan)

cell_position_mm(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) =
  cell_mm(scan) * Vec3f(jx-1, jy-1, jz-1)

cell_position_px(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) =
  500f0 * Vec3f(jx-1, jy-1, jz-1)

cell_range_mm(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) =
  (cell_position_mm(scan, jy, jx, jz), cell_position_mm(scan, jy+1, jx+1, jz+1))

cell_center_mm(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) = begin
  p0, p1 = cell_range_mm(scan, jy, jx, jz)
  (p0 + p1) / 2f0
end

scroll_radius_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  core = scroll_core_mm(scan)
  @assert !isnothing(core) "Scan doesn't have core data."
  o = core[jz]
  p = cell_center_mm(scan, jy, jx, jz)
  @assert abs(p[3] - o[3]) < 0.1f0 "Expected core and cell points to be at the same z coordinate."
  normalize(p - o)
end

cell_containing_mm(scan::HerculaneumScan, p) = begin
  jx, jy, jz = Int.(div.(p, cell_mm(scan))) .+ 1
  (jy, jx, jz)
end

"""
  small_size(scan::HerculaneumScan)

The size of the "small" array, the scan data downsampled by 10.
"""
@inline small_size(scan::HerculaneumScan) =
  (length(1:SMALLER_BY:scan.height), length(1:SMALLER_BY:scan.width), length(1:SMALLER_BY:scan.slices))

"""
  grid_size(scan::HerculaneumScan, [dim])

The size of the grid, in number of cells.
"""
@inline grid_size(scan::HerculaneumScan) =
  (ceil(Int, scan.height / CELL_SIZE), ceil(Int, scan.width / CELL_SIZE), ceil(Int, scan.slices / CELL_SIZE) )
@inline grid_size(scan::HerculaneumScan, dim::Int) =
  grid_size(scan)[dim]

"""
  cell_range(j::Int, [max::Int])

The range of voxel indices within a grid cell.
"""
@inline cell_range(j::Int, max::Int) =
  CELL_SIZE*(j - 1) + 1 : min(CELL_SIZE*j, max)
@inline cell_range(j::Int) =
  CELL_SIZE*(j - 1) + 1 : CELL_SIZE*j

grid_fill(cells; wrap=0) = begin
  @assert wrap == 0 || wrap == 1  "wrap must be 0 or 1"
  res = Set()
  jzs = [jz for (_, _, jz) in cells]
  for layer = minimum(jzs):maximum(jzs)
    jxs = [jx for (_, jx, jz) in cells if jz == layer]
    min_jxs = minimum(jxs)
    max_jxs = maximum(jxs)
    for line = min_jxs:max_jxs
      jys = [jy for (jy, jx, jz) in cells if jz == layer && jx == line]
      for jy = minimum(jys)-wrap : maximum(jys)+wrap
        push!(res, (jy, line, layer))
        if wrap == 1
          if line == min_jxs  push!(res, (jy, line-1, layer)) end
          if line == max_jxs  push!(res, (jy, line+1, layer)) end
        end
      end
    end
  end
  res
end

cell_containing(p) = begin
  jx, jy, jz = Int.(div.(p, 500)) .+ 1
  (jy, jx, jz)
end

mesh_cells(scan::HerculaneumScan, mesh) = begin
  cells = Set()
  for p = mesh.position
    push!(cells, cell_containing(p))
  end
  cells
end

segment_cells(scan::HerculaneumScan, segment_id) =
  mesh_cells(scan, load_segment_mesh(scan, segment_id))

print_blender_add_cells_code(cells) = begin
  println("cells = [")
  for (jy, jx, jz) = cells  println("  ($(jx-1), $(jy-1), $(jz-1)),") end
  println("]")
  println("from vesuvius import vesuvius")
  println("from importlib import reload; reload(vesuvius)")
  println("vesuvius.add_grid_cells(cells)")
end

@inline cell_origin(jy::Int, jx::Int, jz::Int) =
  Point3f(500f0 * (jx-1), 500f0 * (jy-1), 500f0 * (jz-1))

@inline blender_to_mm(scan::HerculaneumScan, p::Vec3f) =
  cell_mm(scan)*p/5f0

@inline blender_to_px(scan::HerculaneumScan, p::Vec3f) =
  CELL_SIZE*p/5f0

print_thaumato_umbilicus_txt(core_scan::HerculaneumScan, scan791::HerculaneumScan = core_scan) = begin
  # Get the scroll core in mm, and convert it to pixels of scan791 coords.
  # Thaumato assumes 7.91um scans, but I have the scroll 4 umbilicus for the 3.24 scan.
  # This way I'm scaling it from 3.24 to 7.91, which I think should be legal
  # because the data_scrolls page says "All volumes will be aligned to the canonical volume".
  for p = scroll_core_mm(core_scan)
    x, y, z = round.(Int, p / px_mm(scan791))
    println("$(y+500), $(z+500), $(x+500)")
  end
end
