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

const Ints1 = NTuple{1, Int}
const Ints2 = NTuple{2, Int}
const Ints3 = NTuple{3, Int}

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

cell_range_mm(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) =
  (cell_position_mm(scan, jy, jx, jz), cell_position_mm(scan, jy+1, jx+1, jz+1))

cell_center_mm(scan::HerculaneumScan, jy::Real, jx::Real, jz::Real) = begin
  p0, p1 = cell_range_mm(scan, jy, jx, jz)
  (p0 + p1) / 2f0
end

scroll_radius_dir(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  @assert scan == scroll_1_54 "Only scroll_1_54 supported for now."
  o = scroll_1_54_core[jz]
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

mesh_cells(mesh) = begin
  cells = Set()
  for p = mesh.position
    push!(cells, cell_containing(p))
  end
  cells
end

print_blender_add_cells_code(cells) = begin
  println("cells = [")
  for (jy, jx, jz) = cells  println("  ($(jx-1), $(jy-1), $(jz-1)),") end
  println("]")
  println("from vesuvius import vesuvius")
  println("from importlib import reload; reload(vesuvius)")
  println("vesuvius.add_cells(cells)")
end

@inline cell_origin(jy::Int, jx::Int, jz::Int) =
  Point3f(500f0 * (jx-1), 500f0 * (jy-1), 500f0 * (jz-1))
