# This doesn't work right. I (or GeometryBasics, or MeshIO) can't seem to get the
# indexing right. Tried many variations. Damn OffsetInteger!


const FaceIdx = OffsetInteger{-1, UInt32}

delete_backfaces(scan::HerculaneumScan, mesh::Mesh, ref_dir::Vec3f) = begin
  vs = coordinates(mesh)
  fs = faces(mesh)
  ns = normals(mesh)

  n_avg = Vec3f(0f0)
  for (i1, i2, i3) = fs
    n = normalize(ns[i1] + ns[i2] + ns[i3])
    if dot(n, ref_dir) < 0
      n = -n
    end
    n_avg += n
  end
  n_avg = normalize(n_avg)

  new_faces = Int[]
  new_vs = Point3f[]
  new_idxs = Vector{Int}(undef, length(fs)*3)
  new_idxs .= -1
  map_idx!(i::FaceIdx) = begin
    if new_idxs[i] == -1
      push!(new_vs, vs[i])
      new_idxs[i] = length(new_vs)
    end
    new_idxs[i]
  end
  for (i1, i2, i3) = fs
    n = normalize(ns[i1] + ns[i2] + ns[i3])
    # Recto is facing opposite the radial direction which is our n_avg ~ ref_dir.
    if dot(n, n_avg) < 0f0
      j1 = map_idx!(i1)
      j2 = map_idx!(i2)
      j3 = map_idx!(i3)
      append!(new_faces, [j1, j2, j3])
    end
  end
  if length(new_vs) > 0
    Mesh(new_vs, new_faces)
  else
    nothing
  end
end

build_cell_patches(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  patches_dir = cell_patches_dir(scan, jy, jx, jz)
  if isdir(patches_dir)
    return nothing
  end
  mkdir(patches_dir)
  holes = load_cell_holes(scan, jy, jx, jz)
  radius_dir = scroll_radius_dir(scan, jy, jx, jz)
  for (i, hole) in enumerate(holes)
    patch = delete_backfaces(scan, hole, radius_dir)
    if !isnothing(patch)
      save("$patches_dir/$(cell_name(jy, jx, jz))_patch_$i.stl", patch)
    end
  end
  nothing
end

build_cell_patches(scan::HerculaneumScan, cells) = begin
  for c in cells
    println("Building cell patches for cell $c...")
    build_cell_patches(scan::HerculaneumScan, c...)
  end
  nothing
end
