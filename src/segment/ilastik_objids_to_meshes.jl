using LinearAlgebra, GeometryBasics, MarchingCubes, JLD2


mesh_and_save_hole!(M::Array{UInt32, 3}, i::UInt32, pos::Point3f, filename::String) = begin
  divs = 8
  samples = Float32(divs^3)
  sx, sy, sz = div.(size(M), divs)
  vol = zeros(Float32, (sx, sy, sz))
  for iz = 1:sz, iy = 1:sy, ix = 1:sx
    val = 0f0
    for kz = 1:divs, ky = 1:divs, kx = 1:divs
      inobj = M[divs*(ix-1)+kx, divs*(iy-1)+ky, divs*(iz-1)+kz] == i
      val += Float32(inobj) / samples
    end
    vol[ix, iy, iz] = val - 0.5f0
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
    msh.position .+= pos
    # TODO: There's a little delta that's missing and must be added here. When
    # imported into blender the meshes don't reach the full cell bounds on the
    # three "p1" faces. They need to be moved by 0.06 blender units (6 px here)
    # to align fully. After that the mesh has equal padding of 0.06 from all
    # faces of the cell. Why 6px? Not sure. 
    msh.position .+= Vec3f(6f0)
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
    mesh_and_save_hole!(M, UInt32(id), pos, "$(file_prefix)$(id).stl")
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
