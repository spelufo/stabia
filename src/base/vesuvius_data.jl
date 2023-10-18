
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

