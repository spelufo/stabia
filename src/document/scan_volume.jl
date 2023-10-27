# Not currently in use. Will revisit or rewrite when/if going to multiple cells.

# TODO:
# - Generalize to multiple loaded cells


mutable struct ScanVolume <: AbstractArray{N0f16, 3}
  scan :: HerculaneumScan

  small :: Array{N0f16, 3}  # A downsampled by SMALLER_BY version of the scan.
  small_size :: Ints3  # small is padded, this is the size of the data
  small_loaded :: Bool
  small_texture :: UInt32

  j :: Ints3
  cell :: Array{N0f16, 3}  # The currently loaded cell, at full scan resolution.
  cell_size :: Ints3 # cell is padded, this is the size of the data
  cell_loaded :: Bool
  cell_texture :: UInt32
end

ScanVolume(scan::HerculaneumScan; load_small=false) = begin
  println("Alloc")
  @time begin
    small_sz = small_size(scan)
    small = zeros(N0f16, gpu_ceil.(small_sz))
    cell_sz = (CELL_SIZE, CELL_SIZE, CELL_SIZE)
    cell = zeros(N0f16, gpu_ceil.(cell_sz))
  end
  scanvol = ScanVolume(
    scan,
    small, small_sz, false, 0,
    (0,0,0), cell, cell_sz, false, 0,
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
  if !scanvol.small_loaded
    println("Loading small volume...")
    @time begin
      data = channelview(load_small_volume(scanvol.scan))
      scanvol.small[1:size(data,1), 1:size(data,2), 1:size(data,3)] .= data
      scanvol.small_loaded = true
    end
  end
  nothing
end

focus_on_cell!(scanvol::ScanVolume, jy::Int, jx::Int, jz::Int) = begin
  if !have_cell(scanvol.scan, jy, jx, jz)
    println("focus_on_cell!: cell $((jy, jx, jz)) not found.")
    return
  end
  if scanvol.j[1] != jy || scanvol.j[2] != jx || scanvol.j[3] != jz
    scanvol.cell_loaded = false
  end
  if !scanvol.cell_loaded
    println("Loading cell...")
    @time begin
      data = channelview(load_cell(scanvol.scan, jy, jx, jz))
      scanvol.cell[1:CELL_SIZE, 1:CELL_SIZE, 1:CELL_SIZE] .= data
      scanvol.j = (jy, jx, jz)
      scanvol.cell_loaded = true
    end
  end
  nothing
end

@inline dimensions(scanvol::ScanVolume) =
  scan_dimensions_mm(scanvol.scan)

@inline cell_position(scanvol::ScanVolume) = begin
  cry = cell_range(scanvol.j[1], scanvol.scan.height)
  crx = cell_range(scanvol.j[2], scanvol.scan.width)
  crz = cell_range(scanvol.j[3], scanvol.scan.slices)
  ( scan_position_mm(scanvol.scan, crx.start, cry.start, crz.start),
    scan_position_mm(scanvol.scan, crx.stop, cry.stop, crz.stop) )
end

@inline grid_size(scanvol::ScanVolume) =
  grid_size(scanvol.scan)

@inline grid_size(scanvol::ScanVolume, dim::Int) =
  grid_size(scanvol.scan, dim)

move_focus!(scanvol::ScanVolume, djy::Int, djx::Int, djz::Int) =
  focus_on_cell!(scanvol,
    min(max(1, scanvol.j[1]+djy), grid_size(scanvol, 1)),
    min(max(1, scanvol.j[2]+djx), grid_size(scanvol, 2)),
    min(max(1, scanvol.j[3]+djz), grid_size(scanvol, 3)))


# Array ########################################################################

# NOTE: I think this can be improved a lot but for now I'm not going to be
# using it as an array all that much. I'll load scanvol.small and scanvol.cell into
# GPU textures.

@inline Base.size(scanvol::ScanVolume) =
  (scanvol.scan.height, scanvol.scan.width, scanvol.scan.slices)

@inline Base.getindex(scanvol::ScanVolume, iy::Int, ix::Int, iz::Int) = begin
  cry = cell_range(scanvol.j[1], scanvol.scan.height)
  crx = cell_range(scanvol.j[2], scanvol.scan.width)
  crz = cell_range(scanvol.j[3], scanvol.scan.slices)
  if iy in cry && ix in crx && iz in crz
    scanvol.cell[iy-cry.start+1, ix-crx.start+1, iz-crz.start+1]
  else
    # TODO: Interpolation, maybe. Only if we need it.
    scanvol.small[div(iy-1, SMALLER_BY)+1, div(ix-1, SMALLER_BY)+1, div(iz-1, SMALLER_BY)+1]
  end
end

# Is this one needed too?
# @inline Base.getindex(scanvol::ScanVolume, i::Int) =


# Render #######################################################################

load_textures(scanvol::ScanVolume) = begin
  if scanvol.small_texture > 0
    println("WARNING: load_textures recreating small_texture")
    glDeleteTextures(1, Ref(scanvol.small_texture))
  end
  id = Ref(UInt32(0))
  glGenTextures(1, id)
  scanvol.small_texture = id[]
  glBindTexture(GL_TEXTURE_3D, scanvol.small_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  # Texture too large under linux+nvidia. Do a dummy chunk of 32^3.
  # h, w, d = size(scanvol.small)
  # glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, scanvol.small)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, 32, 32, 32, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, scanvol.small)

  if scanvol.cell_texture > 0
    println("WARNING: load_textures recreating cell_texture")
    glDeleteTextures(1, Ref(scanvol.cell_texture))
  end
  id = Ref(UInt32(0))
  glGenTextures(1, id)
  scanvol.cell_texture = id[]
  glBindTexture(GL_TEXTURE_3D, scanvol.cell_texture)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  h, w, d = size(scanvol.cell)
  glTexImage3D(GL_TEXTURE_3D, 0, GL_R16UI, h, w, d, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, scanvol.cell)
end

set_textures(scanvol::ScanVolume, shader::Shader) = begin
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_3D, scanvol.small_texture)

  glActiveTexture(GL_TEXTURE1)
  glBindTexture(GL_TEXTURE_3D, scanvol.cell_texture)

  glUniform3f(glGetUniformLocation(shader, "SmallScale"),
    (Float32.(scanvol.small_size./size(scanvol.small)))...)
  glUniform3f(glGetUniformLocation(shader, "CellScale"),
    (Float32.(scanvol.cell_size./size(scanvol.cell)))...)

  glUniform1i(glGetUniformLocation(shader, "Small"), 0)
  glUniform1i(glGetUniformLocation(shader, "Cell"), 1)
end


# GL uniforms.

set_uniforms(scanvol::ScanVolume, shader::Shader) = begin
  dims = dimensions(scanvol)
  glUniform3f(glGetUniformLocation(shader, "dimensions"), dims[1], dims[2], dims[3])
  p0, p1 = cell_position(scanvol)
  glUniform3f(glGetUniformLocation(shader, "cellp0"), p0[1], p0[2], p0[3])
  glUniform3f(glGetUniformLocation(shader, "cellp1"), p1[1], p1[2], p1[3])
end
