
build_sadjs_gp_layer(jz::Int) = begin
  cells = collect(filter((row) -> (row[3] == jz), eachrow(scroll_1_54_gp_mask)))
  n = length(cells)
  for (i, (jy, jx, jz)) = enumerate(cells)
    println("\nAdjusting ($jy, $jx, $jz)\t$(round(100*i/n))%")
    @time build_superpixel_adjusted_sheet_labels(scroll_1_54, jy, jx, jz)
  end
end

@inline in_cell_bounds(iy::Int, ix::Int, iz::Int) =
  1 <= ix <= 500 && 1 <= iy <= 500 && 1 <= iz <= 500

@inline in_cell_bounds(v::Vec3f) = begin
  ix, iy, iz = round.(Int, v)
  in_cell_bounds(iy, ix, iz)
end

scroll_1_gp_seg_ids = parse.(UInt64, scroll_1_gp_segments)

# Is segment seg_id_1 is preferable to segment seg_id_2?
@inline segment_gt(seg_id_1, seg_id_2) = begin
  if seg_id_1 in scroll_1_gp_seg_ids && !(seg_id_2 in scroll_1_gp_seg_ids)
    true
  elseif seg_id_2 in scroll_1_gp_seg_ids && !(seg_id_1 in scroll_1_gp_seg_ids)
    false
  else
    seg_id_1 > seg_id_2
  end
end

build_superpixel_adjusted_sheet_labels(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  sadj_dir = cell_sadj_dir(scan, jy, jx, jz)
  if isdir(sadj_dir)
    @warn "sadjs dir exists, skipping cell ($jy,$jx,$jz). $sadj_dir"
    return
  else
    mkdir(sadj_dir)
  end
  cell_str = cell_name(jy, jx, jz)
  cell_origin = Point3f(cell_origin_px(jy, jx, jz))

  spx_labels, spxs, d_spx, _ = load_cell_snic(scan, jy, jx, jz)
  chunks = load_cell_chunks(scan, jy, jx, jz)

  δ = 0.25f0 # Stepping distance in voxels.

  spxs_normals = zeros(Vec3f, length(spxs))
  chunks_centroids = Dict{ChunkId,Vec3f}()

  # Superpixel's chunks. spxs_chunks[spx_id][chunk_id] will be the number of
  # pixels (voxels, really) in superpixel spx_id the chunk chunk_id goes
  # through. Only scroll superpixels are included.
  spxs_chunks = Dict{SuperpixelId,Dict{ChunkId,Int}}(
    spx_id => Dict{ChunkId,Int}() for (spx_id, spx) = enumerate(spxs) if superpixel_is_papyrus(spx)
  )
  for (chunk_id, chunk_mesh) = chunks
    println("Probing superpixels through chunk $chunk_id...")
    points = reinterpret(Vec3f, metafree(coordinates(chunk_mesh)) .- cell_origin)
    chunks_centroids[chunk_id] = sum(points)/length(points)
    ns = normals(chunk_mesh)
    for (i1, i2, i3) = faces(chunk_mesh)
      v1 = points[i1]; v2 = points[i2]; v3 = points[i3]
      if !in_cell_bounds(v1) && !in_cell_bounds(v2) && !in_cell_bounds(v3)
        continue
      end
      n = normalize(ns[i1] + ns[i2] + ns[i3])
      lu = v2 - v1; norm_lu = norm(lu); eu = normalize(lu)
      lv = v3 - v1; norm_lv = norm(lv); ev = normalize(lv)
      if isnan(norm_lu) || isnan(norm_lv)
        continue
      end
      for u = 0f0:δ:norm_lu
        v_range_end = norm_lv*(1f0 - u/norm_lu)
        if isnan(v_range_end)
          continue
        end
        for v = 0f0:δ:v_range_end
          for depth = 3f0:6f0:21f0  # Try offsets into sheet until we hit scroll.
            ix, iy, iz = round.(Int, v1 + u*eu + v*ev - depth*n)
            if !in_cell_bounds(iy, ix, iz) continue end
            spx_id = spx_labels[iy, ix, iz]
            if superpixel_is_papyrus(spxs[spx_id])
              if !haskey(spxs_chunks[spx_id], chunk_id)  spxs_chunks[spx_id][chunk_id] = 0  end
              spxs_chunks[spx_id][chunk_id] += 1
              spxs_normals[spx_id] += n
              break
            end
          end
        end
      end
    end
  end
  spxs_normals .= normalize.(spxs_normals)

  # The bulk of the runtime is before this. ~300s.

  # Save intermediate values of spxs chunks and normals.
  save("$sadj_dir/../spxs_chunks_and_normals.jld2", "spxs_chunks", spxs_chunks, "spxs_normals", spxs_normals, "chunks_centroids", chunks_centroids)
  # spxs_chunks, spxs_normals, chunks_centroids = load("$sadj_dir/../spxs_chunks_and_normals.jld2", "spxs_chunks", "spxs_normals", "chunks_centroids")

  # How many superpixels each chunk touched.
  println("Computing chunk_spx_counts...")
  chunk_spx_counts = Dict{ChunkId,Int}(chunk_id => 0 for (chunk_id, _) = chunks)
  for (spx_id, spx_chunks) = spxs_chunks
    for (chunk_id, _) = spx_chunks
      chunk_spx_counts[chunk_id] += 1
    end
  end

  println("Chunk overlap graph, dedupe and sequence...")

  # Build chunks overlap graph. Used for deduping and sorting chunks.
  chunks_ids = map(first, chunks)
  chunks_overlap_adjm = zeros(Float32, length(chunks_ids), length(chunks_ids))
  for (spx_id, spx_chunks) = spxs_chunks
    for (chunk_id_u, _) = spx_chunks
      u = indexof(chunk_id_u, chunks_ids)
      for (chunk_id_v, _) = spx_chunks
        if chunk_id_u == chunk_id_v 
          continue
        end
        v = indexof(chunk_id_v, chunks_ids)
        # The denominator here is so that the final edge weight ends up adding
        # to 1 in theory when the two sheets are completely overlapping. That
        # way we can interpret the edge weight as an overlap percentage of sorts.
        chunks_overlap_adjm[u, v] += 2f0/(chunk_spx_counts[chunk_id_u]+chunk_spx_counts[chunk_id_v])
      end
    end
  end
  chunks_overlap = SimpleWeightedGraph(chunks_overlap_adjm)

  # Find and remove fully overlapping segments from the graph.
  chunks_rem = []
  chunks_verts_rem = []
  @inline mark_rem!(u, chunk_id_u) = begin
    if !(u in chunks_verts_rem)
      push!(chunks_rem, chunk_id_u)
      push!(chunks_verts_rem, u)
    end
  end
  for e = edges(chunks_overlap)
    u = e.src; v = e.dst
    chunk_id_u = chunks_ids[u]
    chunk_id_v = chunks_ids[v]
    seg_id_u = chunk_segment(chunk_id_u)
    seg_id_v = chunk_segment(chunk_id_v)
    if seg_id_u == seg_id_v # Chunks from the same segment, keep both.
      # We could also dedupe them. There are some cases where the segment
      # retraces itself (20231106155351 @ (8,8,17)).
      continue
    end
    spx_count_u = chunk_spx_counts[chunk_id_u]
    spx_count_v = chunk_spx_counts[chunk_id_v]
    spx_count_overlap = e.weight*(spx_count_u+spx_count_v)/2f0
    # The threshold of 60% might seem low, but higher values don't filter out
    # some sheets that should be removed. Inspecting the values with the print
    # statement below show that most weights are much lower. Still, a tradeoff.
    # print(e); println("\t$chunk_id_u ($spx_count_u) => $chunk_id_v ($spx_count_v)\toverlap: $(round(Int,spx_count_overlap))")
    overlap_threshold = 0.60
    if e.weight > overlap_threshold # Chunks overlap fully.
      if segment_gt(seg_id_u, seg_id_v) # Keep the "best" one.
        mark_rem!(v, chunk_id_v)
      else
        mark_rem!(u, chunk_id_u)
      end
    elseif spx_count_overlap > overlap_threshold*spx_count_u # Chunk u covered by v.
      mark_rem!(u, chunk_id_u)
    elseif spx_count_overlap > overlap_threshold*spx_count_v # Chunk v covered by u.
      mark_rem!(v, chunk_id_v)
    end
    # Now in theory the only case we don't handle well is when the boundaries of
    # two segments overlap partially within a cell, without either covering the
    # other completely... There we'd like to merge them... Hopefully it is rare
    # enough that it doesn't matter, or someone writes a great segment merger.
  end
  # debug_print_graphviz(chunks_overlap, chunks_ids, red_nodes=chunks_verts_rem)
  # The graph vertex numbering changes when we delete nodes, careful...
  sort!(chunks_verts_rem, rev=true)
  for u = chunks_verts_rem
    println("Removed chunk $(chunks_ids[u])")
    rem_vertex!(chunks_overlap, u)
    deleteat!(chunks_ids, u)
  end
  # debug_print_graphviz(chunks_overlap, chunks_ids)

  # TODO: Is there a better way? Yes there is. Do it with respect to the normals
  # instead of the scroll radial direction. I've just rerun labelgen on gp
  # cells so I'll handle this in assembler, but this is a better place for it.
  # Note that in cells near the core sheets could be split with opposing orientations.
  @inline chunk_comes_before(chunk_id_1::ChunkId, chunk_id_2::ChunkId) = begin
    v = chunks_centroids[chunk_id_1] - chunks_centroids[chunk_id_2]
    dot(v, scroll_radius_dir(scan, jy, jx, jz)) < 0
  end

  # Order each component in the graph, by finding the maximum overlap path. The
  # more overlap the more likely the two chunks are adjacent, so this is a way
  # to sort each connected component. Often, there'll be only one component.
  chunks_seqs = []
  iters = 0
  while nv(chunks_overlap) > 0
    @assert iters < 100 "too many iters in chunks_overlap graph mst loop"
    gmst, mst_verts = prim_max_spanning_tree(chunks_overlap)
    gmst_path = longest_path(gmst)
    chunks_seq = [chunks_ids[v] for v in gmst_path]
    if chunk_comes_before(chunks_seq[end], chunks_seq[1])
      reverse!(chunks_seq)
    end
    push!(chunks_seqs, chunks_seq)
    # debug_print_graphviz(chunks_overlap, chunks_ids, red_nodes=mst_verts, red_edges=edges(gmst), green_path=gmst_path)
    # Remove the vertices touched by the spanning tree, which must be a whole
    # component of chunks_overlap. Next time around the loop will pick up the
    # next connected component.
    verts_rem = collect(mst_verts)
    sort!(verts_rem, rev=true)
    for u = verts_rem
      rem_vertex!(chunks_overlap, u)
      deleteat!(chunks_ids, u)
    end
    iters += 1
  end
  sort!(chunks_seqs, lt=(chunks_seq_1, chunks_seq_2) -> chunk_comes_before(chunks_seq_1[end], chunks_seq_2[1]))
  chunks_seq = vcat(chunks_seqs...)

  # Chunk's superpixels. The set of superpixels that compose a chunk.
  # Collect the superpixels each chunk covers. Each superpixel is assigned to
  # the chunk in chunks_seq that overlaps the most pixels in it.
  println("Computing chunks_spxs...")
  chunks_spxs = Dict{ChunkId,Set{SuperpixelId}}(
    chunk_id => Set{SuperpixelId}() for (chunk_id, _) = chunks
  )
  for (spx_id, spx_chunks) = spxs_chunks
    for chunk_id = chunks_rem
      delete!(spx_chunks, chunk_id)
    end
    if !isempty(spx_chunks)
      chunk_pxs_max, chunk_id_max = findmax(spx_chunks)
      chunk_id_best = chunk_id_max
      if length(spx_chunks) > 1
        # If there are more chunks touching the superpixel and chunk_id_max
        # doesn't win by too much...
        delete!(spx_chunks, chunk_id_max)
        chunk_pxs_second_max, chunk_id_second_max = findmax(spx_chunks)
        if chunk_pxs_second_max > 0.75 * chunk_pxs_max
          # Include the spx in both chunks. This breaks the uniqueness of the
          # assignment, but I want to see how it does.
          push!(chunks_spxs[chunk_id_second_max], spx_id)
          # TODO: Try other criteria, e.g. neighborhood flatness.
          # 1. Grab spx neighbors of each chunk_id.
          # 2. Sum edge deltas from spx_normal.
        end
        spx_chunks[chunk_id_max] = chunk_pxs_max
      end
      push!(chunks_spxs[chunk_id_best], spx_id)
    end
  end

  # We store the superpixel ids for each chunk, and the chunk sequence.
  # This and spx_labels from load_cell_snic are enough to build sheet masks.
  # println("Save chunks_spxs...")
  save("$sadj_dir/chunks_spxs.jld2", "chunks_spxs", chunks_spxs, "chunks_seq", chunks_seq, "chunks_rem", chunks_rem)

  # Save as point clouds.
  println("Compute and save point clouds...")
  for (iseq, chunk_id) = enumerate(chunks_seq)
    chunk_spxs = chunks_spxs[chunk_id]
    chunk_centers = Vec3f[]
    chunk_centers_normals = Vec3f[]
    chunk_fronts = Vec3f[]
    chunk_fronts_normals = Vec3f[]
    for spx_id = chunk_spxs
      spx = spxs[spx_id]
      p = Vec3f(spx.x, spx.y, spx.z)
      n = spxs_normals[spx_id]
      push!(chunk_centers, p)
      push!(chunk_centers_normals, n)
      δn = δ*n
      id = spx_id
      while id == spx_id
        ix, iy, iz = round.(Int, p)
        if !(1 <= ix <= 500 && 1 <= iy <= 500 && 1 <= iz <= 500) break end
        id = spx_labels[iy, ix, iz]
        p += δn
      end
      if !(id in chunk_spxs)
        push!(chunk_fronts, p)
        push!(chunk_fronts_normals, n)
      end
    end
    if length(chunk_centers) > 0
      path = "$sadj_dir/$(cell_str)_sadj_centers_$(zpad(iseq,2))_$(chunk_id).ply"
      save_point_cloud!(path, cell_origin, chunk_centers, chunk_centers_normals)
    end
    if length(chunk_fronts) > 0
      path = "$sadj_dir/$(cell_str)_sadj_fronts_$(zpad(iseq,2))_$(chunk_id).ply"
      save_point_cloud!(path, cell_origin, chunk_fronts, chunk_fronts_normals)
    end
  end

  # Save as meshes. ~130s.
  # println("Compute and save meshes...")
  # M = zeros(UInt32, 500, 500, 500)
  # for (iseq, chunk_id) = enumerate(chunks_seq)
  #   println("Meshing chunk $iseq $chunk_id...")
  #   chunk_spxs = chunks_spxs[chunk_id]
  #   M[:] .= 0x0000_0000
  #   for i = 1:length(M)
  #     if spx_labels[i] in chunk_spxs
  #       M[i] = 0x0000_0001
  #     end
  #   end
  #   path = "$sadj_dir/$(cell_str)_sadj_$(zpad(iseq,2))_$(chunk_id).stl"
  #   mesh_and_save_id!(M, 0x0000_0001, cell_origin, path)
  # end

  return chunks_spxs, chunks_seq, chunks_rem
end

prim_max_spanning_tree(g::SimpleWeightedGraph{V,W}) where {V,W} = begin
  mst = prim_mst(g, one(W)./weights(g))
  gmst = SimpleWeightedDiGraph(nv(g))
  verts = Set{V}(1)
  for e = mst
    w = get_weight(g, e.src, e.dst)
    add_edge!(gmst, e.src, e.dst, w)
    push!(verts, e.src, e.dst)
  end
  gmst, verts
end

flip_edge!(g::SimpleWeightedDiGraph{V,W}, u::V, v::V) where {V,W} = begin
  w = get_weight(g, u, v)
  rem_edge!(g, u, v)
  add_edge!(g, v, u, w)
end

path_to_furthest_leaf(gmst::SimpleWeightedDiGraph{V,W}, u::V) where {V,W} = begin
  l_max = 0
  path_max = []
  for v = outneighbors(gmst, u)
    l, path = path_to_furthest_leaf(gmst, v)
    w = get_weight(gmst, u, v)
    if l + w > l_max
      l_max = l + w
      path_max = path
    end
  end
  insert!(path_max,1,u)
  return l_max, path_max
end

longest_path(gmst::SimpleWeightedDiGraph{V,W}) where {V,W} = begin
  # I expect that the root of the MST will always be vertex 1. It isn't documented
  # anywhere, but I've read prim_mst and think that it should be the case.
  root = 1
  _, path = path_to_furthest_leaf(gmst, 1)
  s = last(path)
  for i = 1:length(path)-1
    u = path[i]; v = path[i+1]
    flip_edge!(gmst, u, v)
  end
  _, path = path_to_furthest_leaf(gmst, s)
  path
end

save_point_cloud!(path, cell_origin::Point3f, points::Vector{Vec3f}, normals::Vector{Vec3f}) = begin
  points = Point3f.(points)
  points .+= cell_origin
  mesh = Mesh(meta(points; normals=normals), Int[])
  save(path, mesh)
end

mesh_and_save_superpixels!(
  scan::HerculaneumScan, jy::Int, jx::Int, jz::Int,
  spx_labels::Array{SuperpixelId, 3}, spxs::Superpixels,
) = begin
  spxs_dir = cell_sadj_dir(scan, jy, jx, jz) * "/spxs"
  isdir(spxs_dir) || mkdir(spxs_dir)
  M = zeros(UInt32, 500, 500, 500)
  for (spx_id, spx) = enumerate(spxs)
    if superpixel_is_papyrus(spx)
      M .= UInt32.(spx_labels .== spx_id)
      cell_origin = Point3f(cell_origin_px(jy, jx, jz))
      mesh_and_save_id!(M, UInt32(true), cell_origin, "$spxs_dir/spx_$(zpad(spx_id,5)).stl")
    end
  end
end

debug_print_graphviz(chunks_overlap, chunks_ids; red_nodes=[], red_edges=[], green_path=[]) = begin
  println("digraph {")
  for v = 1:nv(chunks_overlap)
    chunk_id = chunks_ids[v]
    if v in red_nodes
      println("  $v [label=\"$chunk_id\", color=red];")
    else
      println("  $v [label=\"$chunk_id\"];")
    end
  end
  for e = edges(chunks_overlap)
    u = e.src; v = e.dst; w = round(Int, e.weight*100)
    uid = chunks_ids[u]; chunk_id = chunks_ids[v]
    if u in green_path && v in green_path && (indexof(u, green_path) - indexof(v, green_path)) == 1
      println("  $v -> $u [weight=$w, color=green3 label=\"$w\"];")
    elseif u in green_path && v in green_path && (indexof(u, green_path) - indexof(v, green_path)) == -1
      println("  $u -> $v [weight=$w, color=green3 label=\"$w\"];")
    elseif e in red_edges
      println("  $u -> $v [weight=$w, color=red label=\"$w\"];")
    elseif reverse(e) in red_edges
      println("  $v -> $u [weight=$w, color=red label=\"$w\"];")
    else
      println("  $u -> $v [weight=$w, dir=none, label=\"$w\"];")
    end
    if w > 80
      println("  {rank=same; $u; $v};")
    end
  end
  println("}")
end

sadjs_mask(
  spx_labels::Array{SuperpixelId, 3}, spxs::Superpixels,
  chunks_spxs::Dict{ChunkId,Set{SuperpixelId}}, chunks_seq, chunks_rem
) = begin
  M = zeros(Int8, size(spx_labels))
  spxs_chunks = Dict(spx_id => chunk_id for (chunk_id, spx_ids) = chunks_spxs for spx_id = spx_ids)
  for (i, spx_id) = enumerate(spx_labels)
    if haskey(spxs_chunks, spx_id)
      M[i] = indexof(spxs_chunks[spx_id], chunks_seq)
    elseif superpixel_is_papyrus(spxs[spx_id])
      M[i] = -1
    end
  end

  colors = distinguishable_colors(length(chunks_seq)+2)
  colors[1], colors[2] = colors[2], colors[1]
  C = zeros(RGB{Float32}, size(spx_labels))
  for i = -1:length(chunks_seq)
    C[M .== i] .= colors[i+2]
  end

  M, C
end
