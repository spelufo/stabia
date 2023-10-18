

mutable struct ScanVolume <: AbstractArray{N0f16, 3}
  scan :: HerculaneumScan
  # A downsampled by SMALLER_BY version of the scan.
  small :: Array{N0f16, 3} 
  small_size :: Tuple{Int, Int, Int} # small is padded, this is the size of the data
  # The currently loaded cell, at full scan resolution.
  cell :: Array{N0f16, 3}
  cell_size :: Tuple{Int, Int, Int} # cell is padded, this is the size of the data
  # The grid coordinates of the loaded cell.
  jy :: Int
  jx :: Int
  jz :: Int

  small_texture :: UInt32
  cell_texture :: UInt32
end

focus_on_cell!(vol::ScanVolume, jy::Int, jx::Int, jz::Int) = begin
  if !have_grid_cell(vol.scan, jy, jx, jz)
    println("focus_on_cell!: cell $((jy, jx, jz)) not found.")
    return
  end
  data = channelview(load_grid_cell(vol.scan, jy, jx, jz))
  vol.cell[1:GRID_SIZE, 1:GRID_SIZE, 1:GRID_SIZE] .= data
  vol.jy = jy; vol.jx = jx; vol.jz = jz
  return
end

@inline gpu_ceil(x::Int) = begin
  np = nextpow(2, x)
  np - x < 32 ? np : (div(x, 2)+1)*2
end

ScanVolume(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  small_sz = small_size(scan)
  small = zeros(N0f16, gpu_ceil.(small_sz))
  data = channelview(load_small_volume(scan))
  small[1:size(data,1), 1:size(data,2), 1:size(data,3)] .= data
  cell_sz = (GRID_SIZE, GRID_SIZE, GRID_SIZE)
  cell = zeros(N0f16, gpu_ceil.(cell_sz))
  vol = ScanVolume(scan, small, small_sz, cell, cell_sz, 0, 0, 0, 0, 0)
  focus_on_cell!(vol, jy, jx, jz)
  vol
end

@inline dimensions(vol::ScanVolume) =
  scan_dimensions_mm(vol.scan)

@inline cell_position(vol::ScanVolume) = begin
  cry = grid_cell_range(vol.jy, vol.scan.height)
  crx = grid_cell_range(vol.jx, vol.scan.width)
  crz = grid_cell_range(vol.jz, vol.scan.slices)
  ( scan_position_mm(vol.scan, crx.start, cry.start, crz.start),
    scan_position_mm(vol.scan, crx.stop, cry.stop, crz.stop) )
end

@inline grid_size(vol::ScanVolume) =
  grid_size(vol.scan)

@inline grid_size(vol::ScanVolume, dim::Int) =
  grid_size(vol.scan, dim)

move_focus!(vol::ScanVolume, djy::Int, djx::Int, djz::Int) =
  focus_on_cell!(vol,
    min(max(1, vol.jy+djy), grid_size(vol, 1)),
    min(max(1, vol.jx+djx), grid_size(vol, 2)),
    min(max(1, vol.jz+djz), grid_size(vol, 3)))


# Textures #####################################################################

load_textures(vol::ScanVolume) = begin
  if vol.small_texture <= 0
    id = Ref(UInt32(0))
    glGenTextures(1, id)
    vol.small_texture = id[]
  end
  glBindTexture(GL_TEXTURE_3D, vol.small_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(vol.small)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, vol.small)

  if vol.cell_texture <= 0
    id = Ref(UInt32(0))
    glGenTextures(1, id)
    vol.cell_texture = id[]
  end
  glBindTexture(GL_TEXTURE_3D, vol.cell_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(vol.cell)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, vol.cell)
end

set_textures(vol::ScanVolume) = begin
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_3D, vol.small_texture)

  glActiveTexture(GL_TEXTURE1)
  glBindTexture(GL_TEXTURE_3D, vol.cell_texture)

  glUniform3f(glGetUniformLocation(ed.shader, "SmallScale"),
    (Float32.(vol.small_size./size(vol.small)))...)
  glUniform3f(glGetUniformLocation(ed.shader, "CellScale"),
    (Float32.(vol.cell_size./size(vol.cell)))...)

  glUniform1i(glGetUniformLocation(ed.shader, "Small"), 0)
  glUniform1i(glGetUniformLocation(ed.shader, "Cell"), 1)
end


# Array ########################################################################

# NOTE: I think this can be improved a lot but for now I'm not going to be
# using it as an array all that much. I'll load vol.small and vol.cell into
# GPU textures.

@inline Base.size(vol::ScanVolume) =
  (vol.scan.height, vol.scan.width, vol.scan.slices)

@inline Base.getindex(vol::ScanVolume, iy::Int, ix::Int, iz::Int) = begin
  cry = grid_cell_range(vol.jy, vol.scan.height)
  crx = grid_cell_range(vol.jx, vol.scan.width)
  crz = grid_cell_range(vol.jz, vol.scan.slices)
  if iy in cry && ix in crx && iz in crz
    vol.cell[iy-cry.start+1, ix-crx.start+1, iz-crz.start+1]
  else
    # TODO: Interpolation, maybe. Only if we need it.
    vol.small[div(iy-1, SMALLER_BY)+1, div(ix-1, SMALLER_BY)+1, div(iz-1, SMALLER_BY)+1]
  end
end

# Is this one needed too?
# @inline Base.getindex(vol::ScanVolume, i::Int) =

