struct HerculaneumScan
  volpkg_path :: String
  id :: String
  resolution_um :: Float32
  xray_energy_KeV :: Float32
  width::Int
  height::Int
  slices::Int
end

# Multiply by this to convert scan voxels to millimeters.
# A bit of a hardcoding for expedience...
const mm = 7.91f0 / 1000f0

@inline scan_dimensions_mm(scan::HerculaneumScan) =
  scan.resolution_um * Vec3f(scan.width, scan.height, scan.slices) / 1000f0

@inline scan_position_mm(scan::HerculaneumScan, iy::Int, ix::Int, iz::Int) =
  scan.resolution_um * Vec3f(ix-1, iy-1, iz-1) / 1000f0

const SMALLER_BY = 10

@inline small_size(scan::HerculaneumScan) =
  ( length(1:SMALLER_BY:scan.height),
    length(1:SMALLER_BY:scan.width),
    length(1:SMALLER_BY:scan.slices) )

const GRID_CELL_SIZE = 500

"""
  grid_size(scan::HerculaneumScan, [dim])

The size of the grid, in number of cells.
"""
@inline grid_size(scan::HerculaneumScan) =
  ( ceil(Int, scan.height / GRID_CELL_SIZE),
    ceil(Int, scan.width / GRID_CELL_SIZE),
    ceil(Int, scan.slices / GRID_CELL_SIZE) )

@inline grid_size(scan::HerculaneumScan, dim::Int) =
  grid_size(scan)[dim]

"""
  grid_cell_range(j::Int, [max::Int])

The range of voxel indices within a grid cell.
"""
@inline grid_cell_range(j::Int, max::Int) =
  GRID_CELL_SIZE*(j - 1) + 1 : min(GRID_CELL_SIZE*j, max)

@inline grid_cell_range(j::Int) =
  GRID_CELL_SIZE*(j - 1) + 1 : GRID_CELL_SIZE*j


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

mesh_grid_cells(mesh) = begin
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
  println("vesuvius.add_grid_cells(cells)")
end


@inline grid_cell_origin(jy::Int, jx::Int, jz::Int) =
  Point3f(500f0 * (jx-1), 500f0 * (jy-1), 500f0 * (jz-1))
