# TODO:
# - Load on background thread
# - Generalize to multiple loaded cells?


mutable struct ScanVolume <: AbstractArray{N0f16, 3}
  scan :: HerculaneumScan

  small :: Array{N0f16, 3}  # A downsampled by SMALLER_BY version of the scan.
  small_size :: Tuple{Int, Int, Int}  # small is padded, this is the size of the data

  cell :: Array{N0f16, 3}  # The currently loaded cell, at full scan resolution.
  cell_size :: Tuple{Int, Int, Int} # cell is padded, this is the size of the data
  jy :: Int
  jx :: Int
  jz :: Int

  small_texture :: UInt32
  cell_texture :: UInt32
end

ScanVolume(scan::HerculaneumScan; load_small=false) = begin
  println("Alloc")
  @time begin
    small_sz = small_size(scan)
    small = zeros(N0f16, gpu_ceil.(small_sz))
    cell_sz = (GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)
    cell = zeros(N0f16, gpu_ceil.(cell_sz))
  end
  scanvol = ScanVolume(
    scan,
    small, small_sz,
    cell, cell_sz,
    0, 0, 0,
    0, 0
  )
  if load_small
    load_small!(scanvol)
  end
  scanvol
end

ScanVolume(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  scanvol = ScanVolume(scan)
  focus_on_cell!(scanvol, jy, jx, jz)
  scanvol
end

load_small!(scanvol::ScanVolume) = begin
  println("Loading small volume...")
  @time begin
    data = channelview(load_small_volume(scanvol.scan))
    scanvol.small[1:size(data,1), 1:size(data,2), 1:size(data,3)] .= data
  end
end

focus_on_cell!(scanvol::ScanVolume, jy::Int, jx::Int, jz::Int) = begin
  if !have_grid_cell(scanvol.scan, jy, jx, jz)
    println("focus_on_cell!: cell $((jy, jx, jz)) not found.")
    return
  end
  println("Loading cell...")
  @time begin
    data = channelview(load_grid_cell(scanvol.scan, jy, jx, jz))
    scanvol.cell[1:GRID_CELL_SIZE, 1:GRID_CELL_SIZE, 1:GRID_CELL_SIZE] .= data
    scanvol.jy = jy; scanvol.jx = jx; scanvol.jz = jz
  end
  nothing
end

@inline dimensions(scanvol::ScanVolume) =
  scan_dimensions_mm(scanvol.scan)

@inline cell_position(scanvol::ScanVolume) = begin
  cry = grid_cell_range(scanvol.jy, scanvol.scan.height)
  crx = grid_cell_range(scanvol.jx, scanvol.scan.width)
  crz = grid_cell_range(scanvol.jz, scanvol.scan.slices)
  ( scan_position_mm(scanvol.scan, crx.start, cry.start, crz.start),
    scan_position_mm(scanvol.scan, crx.stop, cry.stop, crz.stop) )
end

@inline grid_size(scanvol::ScanVolume) =
  grid_size(scanvol.scan)

@inline grid_size(scanvol::ScanVolume, dim::Int) =
  grid_size(scanvol.scan, dim)

move_focus!(scanvol::ScanVolume, djy::Int, djx::Int, djz::Int) =
  focus_on_cell!(scanvol,
    min(max(1, scanvol.jy+djy), grid_size(scanvol, 1)),
    min(max(1, scanvol.jx+djx), grid_size(scanvol, 2)),
    min(max(1, scanvol.jz+djz), grid_size(scanvol, 3)))


# Array ########################################################################

# NOTE: I think this can be improved a lot but for now I'm not going to be
# using it as an array all that much. I'll load scanvol.small and scanvol.cell into
# GPU textures.

@inline Base.size(scanvol::ScanVolume) =
  (scanvol.scan.height, scanvol.scan.width, scanvol.scan.slices)

@inline Base.getindex(scanvol::ScanVolume, iy::Int, ix::Int, iz::Int) = begin
  cry = grid_cell_range(scanvol.jy, scanvol.scan.height)
  crx = grid_cell_range(scanvol.jx, scanvol.scan.width)
  crz = grid_cell_range(scanvol.jz, scanvol.scan.slices)
  if iy in cry && ix in crx && iz in crz
    scanvol.cell[iy-cry.start+1, ix-crx.start+1, iz-crz.start+1]
  else
    # TODO: Interpolation, maybe. Only if we need it.
    scanvol.small[div(iy-1, SMALLER_BY)+1, div(ix-1, SMALLER_BY)+1, div(iz-1, SMALLER_BY)+1]
  end
end

# Is this one needed too?
# @inline Base.getindex(scanvol::ScanVolume, i::Int) =

