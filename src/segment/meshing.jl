using LinearAlgebra, GeometryBasics, MarchingCubes, JLD2


mesh_and_save_id!(M::Array{UInt32, 3}, i::UInt32, pos::Point3f, filename::String; holes::Bool = false) = begin
  divs = holes ? 8 : 4
  samples = Float32(divs^3)
  sx, sy, sz = div.(size(M), divs)
  vol = zeros(Float32, (sx, sy, sz))
  for iz = 1:sz, iy = 1:sy, ix = 1:sx
    val = 0f0
    for kz = 1:divs, ky = 1:divs, kx = 1:divs
      inobj = M[divs*(ix-1)+kx, divs*(iy-1)+ky, divs*(iz-1)+kz] == i
      val += Float32(inobj) / samples
    end
    if holes
      vol[ix, iy, iz] = val - 0.5f0
    else
      vol[iy, ix, iz] = 0.5f0 - val
    end
  end
  mc = MC(vol)
  # mc = MC(Float32(0.5) .- Float32.(M .== i))
  march(mc)

  println("Meshing ($(length(mc.vertices)) vertices)...")
  if length(mc.vertices) < 3
    println("not enough vertices")
  else
    msh = MarchingCubes.makemesh(GeometryBasics, mc)
    msh.position .*= Float32(divs)
    msh.position .+= pos + Vec3f(divs - 2)
    save(filename, msh)
  end
  nothing
end

hole_ids_to_meshes(hole_ids_file::String, file_prefix::String, pos::Point3f) = begin
  f = h5open(hole_ids_file)
  M = f["exported_data"][1, :, :, :, 1]
  n = maximum(M)
  close(f)
  for id = 1:n
    println("Building mesh for hole $id / $n ... ")
    mesh_and_save_id!(M, UInt32(id), pos, "$(file_prefix)$(id).stl"; holes = true)
  end
end


# In Blender:
# import bpy
# holes = []
# for obj in bpy.data.collections["Holes"].objects:
#   y = obj.bound_box[0][1]
#   holes.append((y, obj.name))
# for i, (y, name) in enumerate(sorted(holes)):
#   obj = bpy.data.collections["Holes"].objects[name]
#   obj.name = f"hole_{i}_was_{name}"


potential_to_meshes(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  sheet_dir = potential_sheet_dir(scan, jy, jx, jz)
  if !isdir(sheet_dir)
    mkdir(sheet_dir)
    file_prefix = "$sheet_dir/$(cell_name(jy, jx, jz))_sheet_"
    pos = Point3f(500f0 * (jx-1), 500f0 * (jy-1), 500f0 * (jz-1))
    P = load_cell_probabilities(scan, jy, jx, jz)
    ϕ, S = load_cell_potential(scan, jy, jx, jz)
    M = floor.(UInt32, ϕ .* (P .> 0.5f0))
    n = maximum(M)
    for id = 1:n
      println("Building mesh for sheet $id / $n ... ")
      mesh_and_save_id!(M, UInt32(id), pos, "$(file_prefix)$(id).stl")
    end
  end
end
