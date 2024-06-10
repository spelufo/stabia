
parse_chunk_name(name::String) = begin
  # e.g. "cell_yxz_007_008_011_sadj_fronts_01_20231016151002006"
  _, _, jy, jx, jz, _, _, i, chunk_id = split(name, "_")
  return parse(Int, jy), parse(Int, jx), parse(Int, jz), parse(Int, i), chunk_id
end

chunk_points_path(scroll::HerculaneumScan, name::String) = begin
  pc_name = replace(name, "chunk_recon" => "fronts")
  joinpath(segmentation_dir(scroll), name[1:20], "sadjs", "$pc_name.ply")
end

build_recon_halves(scroll::HerculaneumScan, out_dir, assembly_file; save_points=true, save_poisson=true) = begin
  lz = grid_size(scroll, 3)
  poisson_cube_length = nextpow(2, maximum(grid_size(scroll))) # 32 for scroll 1.
  poisson_depth = Int(log2(poisson_cube_length)) + 5 # 10
  isdir(out_dir) || mkdir(out_dir)
  isdir("$out_dir/tmp") || mkdir("$out_dir/tmp")

  assembly = JSON.parsefile(assembly_file, dicttype=OrderedDict)
  layer_ojs_by_jz = [layer_oj(scroll, jz) for jz = 1:lz]

  # Read in all the meshes and group them.
  println("\nLoading chunk point clouds...")
  chunks = [Mesh[] for _ = 1:4*length(assembly)]
  jz_ranges = [Int[lz+1, 0] for _ = 1:2*length(assembly)]
  for (turn, (turn_collection_name, turn_chunk_names)) = enumerate(assembly)
    for chunk_name = turn_chunk_names
      jy, jx, jz, _, _ = parse_chunk_name(chunk_name)
      jx_split, jy_split = layer_ojs_by_jz[jz]
      ihalf  = (jx <= jx_split) ? 2 : 1
      iyhalf = (jy <= jy_split) ? 2 : 1
      jz_ranges[2*(turn-1)+ihalf][1] = min(jz_ranges[2*(turn-1)+ihalf][1], jz-1)
      jz_ranges[2*(turn-1)+ihalf][2] = max(jz_ranges[2*(turn-1)+ihalf][2], jz)
      iquarter =
        (ihalf == 1 && iyhalf == 1) ? 1 :
        (ihalf == 1 && iyhalf == 2) ? 2 :
        (ihalf == 2 && iyhalf == 2) ? 3 :
        (ihalf == 2 && iyhalf == 1) ? 4 : 0
      push!(chunks[(turn-1)*4 + iquarter], load(chunk_points_path(scroll, chunk_name)))
    end
  end

  # Run poisson on each half turn. A full turn of points is used, with a quarter
  # before and a quarter after the half turn for extra support. They are clipped
  # from the half turn result mesh.
  for (turn, (turn_collection_name, turn_chunk_names)) = enumerate(assembly)
    turn_name = "turn_$(zpad(turn-1, 2))"
    println("\nReconstructing $turn_name (from $turn_collection_name)...")
    for ihalf = 1:2
      jz_min, jz_max = jz_ranges[2*(turn-1)+ihalf]
      ps = Point3f[]
      ns = Vec3f[]
      iq1 = (ihalf == 1) ? 4*turn - 4 : 4*turn - 2
      for chunks_turn_for_half = @view chunks[max(1,iq1):min(iq1+3, length(chunks))]
        for chunk_points_mesh = chunks_turn_for_half
          append!(ps, metafree(coordinates(chunk_points_mesh)))
          append!(ns, normals(chunk_points_mesh))
        end
      end
      half_name = "$(turn_name)_h$(ihalf)"
      save_points && save_ply("$out_dir/tmp/$(half_name)_points.ply", Mesh(meta(ps, normals=ns), Int[]))
      ps_recon, ns_recon, densities, tris_recon = poisson_recon(
        ps, ns, Vec3f(0), poisson_cube_length*500f0, depth=poisson_depth
      )
      save_poisson && save_ply("$out_dir/tmp/$(half_name)_poisson.ply", Mesh(meta(ps_recon, normals=ns_recon), tris_recon)) #; values=densities)

      filter_mesh!(ps_recon, ns_recon, densities, tris_recon) do ip::Int, p::Point3f
        densities[ip] >= 8f0 || return false
        jz_min*500f0 <= p[3] <= jz_max*500f0 || return false
        # Clip outside the winding boundary. The jz_inc/jz_dec stuff handles
        # vertices at the boundary, all of which we want to keep.
        x = p[1]; y = p[2]; z = p[3]
        jz_inc = clamp(Int(div(z, 500f0)) + 1, 1, lz)
        jz_dec = clamp(lz - Int(div(lz*500 - z, 500f0)), 1, lz)
        jx_split_inc = layer_ojs_by_jz[jz_inc][1]
        jx_split_dec = layer_ojs_by_jz[jz_dec][1]
        if ihalf == 1
          x >= jx_split_inc*500f0 || x >= jx_split_dec*500f0
        else
          x <= jx_split_inc*500f0 || x <= jx_split_dec*500f0
        end
      end
      # The normals will be all zero unless outputGradients is passed to PoissonRecon.
      # Do we want them? Save a little space skipping them for now.
      if length(ps_recon) > 0
        save_ply("$out_dir/$(half_name).ply", Mesh(meta(ps_recon, normals=ns_recon), tris_recon))
      end
    end
  end

end

filter_mesh!(pred::Function, ps::Vector{Point3f}, ns::Vector{Vec3f}, ds::Vector{Float32}, faces::Vector{GLTriangleFace}) = begin
  newindices = Dict{Int,Int}()
  l = 0
  for i = 1:length(ps)
    if pred(i, ps[i])
      l += 1
      newindices[i] = l
      ps[l] = ps[i]
      ns[l] = ns[i]
      ds[l] = ds[i]
    end
  end
  resize!(ps, l)
  resize!(ns, l)
  resize!(ds, l)
  m = 0
  for j = 1:length(faces)
    face = faces[j]
    skipface = false
    for i = face
      if !haskey(newindices, GeometryBasics.value(i))
        skipface = true
        break
      end
    end
    if !skipface
      m += 1
      a, b, c = GeometryBasics.value.(face)
      faces[m] = GLTriangleFace(newindices[a], newindices[b], newindices[c])
    end
  end
  resize!(faces, m)
end
