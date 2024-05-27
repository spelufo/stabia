const FrontsGraph = SimpleWeightedDiGraph{Int,Float32}

assemble_scroll(scroll::HerculaneumScan; output_dir::String = "logs/assembler") = begin
  ly, lx, lz = grid_size(scroll)
  assemble_scroll(scroll, 1, lz, output_dir=output_dir)
end

assemble_scroll_layers_by_oj(scroll::HerculaneumScan; output_dir::String = "logs/assembler") = begin
    # layers_by_oj, _ = group_layers_by_oj(scroll)
  layers_by_oj = [                   # (ojx, ojy)
    [1, 2, 3, 4],                    #   (8, 5)
    [5, 6, 7, 8, 9],                 #   (8, 4)  # alt. [5, 6, 7], [8, 9],
    [10, 11],                        #   (8, 5)
    [12],                            #   (8, 6)
    [13, 14],                        #   (8, 7)
    [15, 16, 17, 18, 19, 20, 21],    #   (7, 7)  # alt. [15, 16, 17, 18], [19, 20, 21],
    [22, 23, 24, 25],                #   (6, 8)
    [26, 27, 28, 29],                #   (6, 9)
  ]
  n = length(layers_by_oj)
  for (i, jzs) = enumerate(layers_by_oj)
    println("Assembling layer group $i/$n: $jzs ...")
    @time assemble_scroll(scroll::HerculaneumScan, jzs[1], jzs[end], output_dir=output_dir)
    println()
  end
end

assemble_scroll(scroll::HerculaneumScan, jz_start::Int, jz_end::Int; output_dir::String = "logs/assembler") = begin
  name = "assembly_jzs_$(zpad(jz_start, 2))_$(zpad(jz_end, 2))"

  println("Building fronts graph...")
  threshold = 2f0
  @show threshold
  g, front_ids, front_is, edges_same, edges_less, edges_wind =
    build_fronts_graph(scroll, jz_start, jz_end, threshold)

  println("Breaking small cycles...")
  max_cycle_length = 12
  @show max_cycle_length
  edges_broken = assembler_break_cycles!(g, front_ids, max_cycle_length, 20)

  println("Leveling...")
  assembly, turns = assembler_leveling(g, front_ids, "$output_dir/$(name)_sccg.dot")

  println("Saving...")

  # Graphviz debug output.
  dot_path = "$output_dir/$(name).dot"
  open(dot_path, "w") do f
    debug_print_fronts_graphviz(front_ids, edges_same, edges_less, edges_wind, front_is, turns, edges_broken, io=f)
  end
  run(`neato -Tsvg $dot_path -o $(replace(dot_path, ".dot"=>".svg"))`)

  # Blender import script output.
  open("$output_dir/$(name).py", "w") do f
    print_blender_import_assembly(scroll, jz_start, jz_end, assembly, io=f)
  end

  # Save the results.
  save("$output_dir/$(name).jld2", "assembly", assembly)

  assembly
end

const wless = 1000f0
const wwind = 1200f0
@inline is_less_edge(w::Float32) = w == wless || w == wwind
@inline is_wind_edge(w::Float32) = w == wwind
@inline is_same_edge(w::Float32) = w < wless

struct PointCloud
  id::FrontId
  points::Vector{Vec3f}
  normals::Vector{Vec3f}
end

Base.isempty(pc::PointCloud) = isempty(pc.points)
Base.length(pc::PointCloud) = length(pc.points)

# I arrived at this by looking at the parts of the svg that don't belong to the
# spiral. I then imported all the potentially problematic cell front_sadjs into
# blender, to see why they cause problems. Took 10 or 20 minutes. A few are
# just reversed. Most are cells that contain the umbilicus so have sheets facing
# each other grouped together. Reversing these doesn't solve the problem, though
# one orientation could be better than the other.
reversed_cells = [
  (5,8,6),
  (5,8,7),
  (5,8,8),
  (6,8,12),
  (5,7,16),
  (5,7,17),
  (5,7,18),
  (5,7,19),
  (7,7,18),
]
skipped_cells = [
  (7,5,26),
  (8,4,26),
  (9,4,26),
]

@inline jz_ojs(scroll::HerculaneumScan, jz::Int) = begin
  o = scroll_core_px(scroll)[jz]
  (round(Int, o[1]/500f0), round(Int, o[2]/500f0))
end

build_fronts_graph(scroll::HerculaneumScan, jz_start::Int, jz_end::Int, threshold::Float32) = begin
  ly, lx, lz = grid_size(scroll)
  front_ids = FrontId[]
  front_is = []
  edges_same = Tuple{FrontId,FrontId,Float32}[] # a -- b  iff w(a) = w(b)
  edges_less = Tuple{FrontId,FrontId,Float32}[] # a -> b  iff w(a) < w(b)
  edges_wind = Tuple{FrontId,FrontId}[]

  # Load all the point clouds.
  # TODO: Don't need all at once, could use less memory.
  println("  Loading point clouds...")
  point_clouds = Array{Vector{PointCloud}}(undef, ly, lx, lz)
  for jz = jz_start:jz_end, jx = 1:lx, jy = 1:ly
    ojx, ojy = jz_ojs(scroll, jz)
    point_clouds[jy, jx, jz] = PointCloud[]
    if have_cell_fronts(scroll, jy, jx, jz)
      lasti = nothing; lastid = nothing
      cell_fronts = load_cell_fronts(scroll, jy, jx, jz)
      (jy,jx,jz) in skipped_cells && continue
      (jy,jx,jz) in reversed_cells && reverse!(cell_fronts)
      for (i, front_id, mesh) = cell_fronts
        push!(front_is, i)
        push!(front_ids, front_id)
        front_points = reinterpret(Vec3f, metafree(coordinates(mesh)))
        front_normals = normals(mesh)
        pc = PointCloud(front_id, front_points, front_normals)
        push!(point_clouds[jy, jx, jz], pc)
        if !isnothing(lasti)
          push!(edges_less, (lastid, front_id, i - lasti))
        end
        lasti = i; lastid = front_id
      end
    end
  end

  # Build the graph's edges by matching adjacent point clouds.
  println("  Matching point clouds at boundaries...")
  @inline point_clouds_ids(pcs::Vector{PointCloud}) = [pc.id for pc = pcs]
  # Grid boundary plane where jy -> jy+1.
  for jz = jz_start:jz_end, jx = 1:lx, jy = 1:ly-1
    pclouds = point_clouds[jy, jx, jz]; qclouds = point_clouds[jy+1, jx, jz]
    if !isempty(pclouds) && !isempty(qclouds)
      pclouds = select_boundary_points_jy(pclouds, jy)
      qclouds = select_boundary_points_jy(qclouds, jy)
      pids = point_clouds_ids(pclouds); qids = point_clouds_ids(qclouds)
      if length(pclouds) > 0 && length(qclouds) > 0
        for (ip, iq, d) = match_boundary(pclouds, qclouds, threshold)
          push!(edges_same, (pids[ip], qids[iq], d))
        end
      end
    end
  end
  # Grid boundary plane where jx -> jx+1.
  for jz = jz_start:jz_end, jx = 1:lx-1, jy = 1:ly
    pclouds = point_clouds[jy, jx, jz]; qclouds = point_clouds[jy, jx+1, jz]
    ojx, ojy = jz_ojs(scroll, jz)
    if !isempty(pclouds) && !isempty(qclouds)
      pclouds = select_boundary_points_jx(pclouds, jx)
      qclouds = select_boundary_points_jx(qclouds, jx)
      pids = point_clouds_ids(pclouds); qids = point_clouds_ids(qclouds)
      if length(pclouds) > 0 && length(qclouds) > 0
        for (ip, iq, d) = match_boundary(pclouds, qclouds, threshold)
          if jx == ojx && jy > ojy
            # Winding boundary. Scroll 1 goes outwards clockwise seen from above.
            push!(edges_less, (pids[ip], qids[iq], 1))
            push!(edges_wind, (pids[ip], qids[iq]))
          # For half turns. I prefer full turns.
          # elseif jx == ojx && jy <= ojy
          #   push!(edges_less, (qids[iq], pids[ip], 1))
          #   push!(edges_wind, (qids[iq], pids[ip]))
          else
            push!(edges_same, (qids[iq], pids[ip], d))
          end
        end
      end
    end
  end
  # Grid boundary plane where jz -> jz+1.
  for jz = jz_start:jz_end-1, jx = 1:lx, jy = 1:ly
    pojx, pojy = jz_ojs(scroll, jz); qojx, qojy = jz_ojs(scroll, jz+1)
    pclouds = point_clouds[jy, jx, jz]; qclouds = point_clouds[jy, jx, jz+1]
    if !isempty(pclouds) && !isempty(qclouds)
      pclouds = select_boundary_points_jz(pclouds, jz)
      qclouds = select_boundary_points_jz(qclouds, jz)
      pids = point_clouds_ids(pclouds); qids = point_clouds_ids(qclouds)
      if length(pclouds) > 0 && length(qclouds) > 0
        for (ip, iq, d) = match_boundary(pclouds, qclouds, threshold)
          if min(pojx, qojx) <= jx < max(pojx, qojx) && min(pojy, qojy) <= jy < max(pojy, qojy)
            # These faces are ambiguous, so don't insert any edges. They must be
            # rare if ocurring at all, so warn about their existence.
            @warn "ambiguous jz->jz+1 boundary"
            @show jz, jz+1, (pojx, pojy), (qojx, qojy)
          elseif pojx <= jx < qojx && jy > ceil(Int, (pojy+qojy)/2)
            push!(edges_wind, (qids[iq], pids[ip]))
          elseif qojx <= jx < pojx && jy > ceil(Int, (pojy+qojy)/2)
            push!(edges_wind, (pids[ip], qids[iq]))
          else
            push!(edges_same, (qids[iq], pids[ip], d))
          end
        end
      end
    end
  end

  # Build a SimpleWeightedDiGraph from the edges.
  # The weights here are not so much scalars as tags. But saving the matching
  # distance for "same" edges as weights is convenient. And if we are going to
  # interpret the to edge weights as distances we should set the "less" edges
  # to a much higher distance, above all "same" edges.
  # The algorithms we want to run should only care about connectivity anyways.
  # TODO: Using a dict instead of indexof(_, front_ids) could be faster.
  @assert wless > 3*threshold "wless needs to be out of the range of same edge matching distances"
  n = length(front_ids)
  if n == 0
    @warn "No fronts, no graph to build."
    return []
  end
  g = SimpleWeightedDiGraph{Int64, Float32}(n)
  for (src, dst, w) = edges_same
    s = indexof(src, front_ids); d = indexof(dst, front_ids)
    add_edge!(g, s, d, w)
    add_edge!(g, d, s, w)
  end
  for (src, dst, w) = edges_less
    s = indexof(src, front_ids); d = indexof(dst, front_ids)
    if (src, dst) in edges_wind
      add_edge!(g, s, d, wwind)
    else
      add_edge!(g, s, d, wless)
    end
  end

  g, front_ids, front_is, edges_same, edges_less, edges_wind
end

turns_to_assembly(turns::Vector{Int}, front_ids::Vector{FrontId}) = begin
  assembly = [FrontId[] for _ = 1:maximum(turns)]
  for (front_id, turn) = zip(front_ids, turns)
    push!(assembly[turn], front_id)
  end
  assembly
end

assembler_break_cycles!(g::SimpleWeightedDiGraph{T, Float32}, orig_ids::Vector{<:Integer}, max_cycle_length::Int, max_cycle_breaking_iters::Int) where {T<:Integer} = begin
  edges_broken = []
  # For assembly, this only runs a single iteration, but that's not a given.
  for _ = 1:max_cycle_breaking_iters
    cycles = badcycles_limited_length(g, max_cycle_length)
    n_cycles = length(cycles)
    @show n_cycles
    n_cycles > 0 || break
    qedges = PriorityQueue{Tuple{T,T}, Int}()
    for cycle = cycles
      src = cycle[end]
      for dst = cycle
        e = (src, dst)
        if !haskey(qedges, e)  qedges[e] = 0  end
        qedges[e] -= 1
        src = dst
      end
    end
    while !isempty(qedges)
      _, prio = peek(qedges)
      src, dst = dequeue!(qedges)
      rem_edge!(g, src, dst)
      push!(edges_broken, (orig_ids[src], orig_ids[dst], get_weight(g, src, dst)))
      n_cycles = length(cycles)
      filter!(cycles) do cycle
        cycle_has_edge(cycle, src, dst) || return true
        # Update the priorities of the edges from solved cycles.
        s = cycle[end]
        for d = cycle
          if haskey(qedges, (s, d))  qedges[(s, d)] += 1  end
          s = d
        end
        false
      end
      n_broken_cycles = n_cycles - length(cycles)
      println("$(orig_ids[src]) -> $(orig_ids[dst]), $(-prio), n_broken_cycles = $n_broken_cycles")
      length(cycles) > 0 || break
    end
  end
  edges_broken
end

cycle_has_edge(cycle::Vector{T}, esrc::T, edst::T) where {T<:Integer} = begin
  src = cycle[end]
  for dst = cycle
    if src == esrc && dst == edst
      return true
    end
    src = dst
  end
  false
end

badcycles_limited_length(g::SimpleWeightedDiGraph{T, Float32}, max_cycle_length::Int) where {T<:Integer} = begin
  cycles = simplecycles_limited_length(g, max_cycle_length)
  filter!(cycles) do cycle
    length(cycle) > 2 || return false
    src = cycle[end]
    for dst = cycle
      if is_less_edge(get_weight(g, src, dst))
        return true
      end
      src = dst
    end
    return false
  end
  cycles
end


assembler_break_cycles_v0!(g::SimpleWeightedDiGraph{Int64, Float32}, front_ids::Vector{FrontId}, max_cycle_length::Int, max_cycle_breaking_iters::Int) = begin
  edges_broken = []
  num_cycles_with_bad_lesses = 0
  num_cycles_broken = 0
  break_cycle!(g, cycle) = begin
    num_cycles_broken += 1
    lcycle = length(cycle)
    lesses = Int[]
    for i = 1:lcycle
      src = cycle[i]; dst = cycle[i%lcycle + 1]
      if has_edge(g, src, dst)
        if is_same_edge(get_weight(g, src, dst)) && has_edge(g, dst, src)
          rem_edge!(g, src, dst)
          rem_edge!(g, dst, src)
          push!(edges_broken, (front_ids[src], front_ids[dst], get_weight(g, src, dst)))
        else
          push!(lesses, i)
          # For vis. Even if we don't break them, I want to see the cycle.
          push!(edges_broken, (front_ids[src], front_ids[dst], get_weight(g, src, dst)))
        end
      end
    end
    if length(lesses) > 1
      # This way we assume the less edges are not the wrong ones, unless the
      # conflict involves more than one of them.
      num_cycles_with_bad_lesses += 1
      for i = lesses
        src = cycle[i]; dst = cycle[i%lcycle + 1]
        rem_edge!(g, src, dst)
        # push!(edges_broken, (front_ids[src], front_ids[dst], get_weight(g, src, dst)))
      end
    end
  end

  cycle_breaking_iters = 0
  while true
    cycle_breaking_iters += 1
    @assert cycle_breaking_iters < max_cycle_breaking_iters "too many cycle breaking iterations"
    cycles = badcycles_limited_length(g, max_cycle_length)
    if length(cycles) == 0
      break
    end
    sort!(cycles, by=length)
    lmin = length(cycles[1])
    broken_cycles = 0
    broken_vertices = Set{Int}()
    for cycle = cycles
      if length(cycle) > lmin  break  end
      break_cycle!(g, cycle)
      broken_cycles += 1
      union!(broken_vertices, cycle)
    end
    @show lmin, broken_cycles
  end
  @show cycle_breaking_iters, num_cycles_broken, num_cycles_with_bad_lesses
  edges_broken
end

assembler_leveling(g::SimpleWeightedDiGraph{Int64, Float32}, front_ids::Vector{FrontId}, sccg_dot_path::String) = begin
  # If all the cycles formed between turns have been broken each SCC only has
  # nodes of the same turn. The condensation will group nodes connected
  # by "same" edges and leave the "less" edges between them. That way we can
  # order them in bulk.
  sccs = strongly_connected_components(g)
  sccg = condensation(g, sccs)
  @show length(weakly_connected_components(sccg))
  levels = Union{Nothing,Int}[nothing for v = 1:nv(sccg)]
  # TODO: We may be able to improve on graphviz leveling and save more manual
  # adjustment time. It is a bit icky to shell out like this but it works.
  # We can get the same result reimplementing the ILP graphviz solves with JuMP.
  open(sccg_dot_path, "w") do f
    debug_print_sccg_graphviz(sccg, levels, io=f)
  end
  run(`dot -Tsvg $sccg_dot_path -o $(replace(sccg_dot_path, ".dot"=>".svg"))`)
  gvnodes = JSON.parse(IOBuffer(read(`dot -Tjson $sccg_dot_path`)))["objects"]
  sccs_by_height = Dict{Float32,Vector{Int}}()
  for gvnode = gvnodes
    v = parse(Int, gvnode["name"])
    h = parse(Float32,split(gvnode["pos"], ",")[2])
    if !haskey(sccs_by_height, h)  sccs_by_height[h] = Int[]  end
    push!(sccs_by_height[h], v)
  end
  L = length(sccs_by_height)
  for (l, (h, v)) = enumerate(sort(sccs_by_height))
    levels[v] .= L - l + 1
    # levels[v] .= l
  end
  for v = 1:length(levels)
    @assert !isnothing(v) "levels[$v] is nothing"
  end

  # Group components and their front_ids by level.
  assembly = [Vector{FrontId}[] for _ = 1:maximum(levels)]
  front_levels = zeros(Int, length(front_ids))
  for (icomponent, component) = enumerate(sccs)
    l = levels[icomponent]
    for i = component
      front_levels[i] = l
    end
    component_front_ids = map(i -> front_ids[i], component)
    push!(assembly[l], component_front_ids)
  end
  assembly, front_levels
end

print_blender_import_assembly(scroll::HerculaneumScan, jz_start::Int, jz_end::Int, assembly::Vector{Vector{Vector{FrontId}}}; io::IO=stdout) = begin
  jztag = "$(zpad(jz_start,2))_$(zpad(jz_end,2))"
  println(io, "import bpy")
  println(io, "from vesuvius.utils import activate_collection")
  for (l, level) = enumerate(assembly)
    turn = "jz_$(jztag)_turn_$(zpad(l, 2))"
    println(io, "turn_col = activate_collection($(repr(turn)))")
    for (icomponent, component) = enumerate(level)
      if length(component) == 1
        println(io, "activate_collection(turn_col)")
        print_blender_imports(map(front_id -> front_id_path(scroll, front_id), component), io=io)
      else
        component_name = "$(turn)_comp_$(zpad(icomponent, 2))"
        println(io, "activate_collection($(repr(component_name)), parent_collection=turn_col)")
        print_blender_imports(map(front_id -> front_id_path(scroll, front_id), component), io=io)
      end
    end
  end
end

print_blender_import_assembly(scroll::HerculaneumScan, jz_start::Int, jz_end::Int, assembly::Vector{Vector{FrontId}}; io::IO=stdout) = begin
  jztag = "$(zpad(jz_start,2))_$(zpad(jz_end,2))"
  println(io, "import bpy")
  println(io, "from vesuvius.utils import activate_collection")
  for (l, level) = enumerate(assembly)
    turn = "jz_$(jztag)_turn_$(zpad(l, 2))"
    println(io, "turn_col = activate_collection($(repr(turn)))")
    print_blender_imports(map(front_id -> front_id_path(scroll, front_id), level), io=io)
  end
end


debug_print_sccg_graphviz(sccg, levels; io::IO=stdout) = begin
  println(io, "digraph {")
  println(io, "  node [style=filled, shape=circle, penwidth=0, fillcolor=\"/paired10/2\"];")
  println(io, "  edge [style=bold];")
  for n = 1:nv(sccg)
    l = something(levels[n], "")
    println(io, "  $n [label=\"$n ($l)\"];")
  end
  for e = edges(sccg)
    src = e.src; dst = e.dst;
    println(io, "  $src -> $dst;")
  end
  println(io, "}")
end

debug_print_fronts_graphviz(front_ids, edges_same, edges_less, edges_wind, front_is, front_levels, edges_broken; io::IO=stdout) = begin
  edges_broken = [(a, b) for (a, b, _) = edges_broken]
  # colorschemes = ["paired10", "set310", "puor10", "piyg10", "prgn10"]
  ncolors = maximum(front_levels) + 1
  colors = colorhex.(distinguishable_colors(ncolors, lchoices=range(40, stop=80, length=5)))
  println(io, "digraph {")
  println(io, "  node [style=filled, shape=circle, penwidth=0];")
  println(io, "  edge [style=bold];")
  o = Vec2f(8, 6) # one for the whole scroll, hopefully it doesn't matter
  for (front_id, i, l) = zip(front_ids, front_is, front_levels)
    jy, jx, jz = front_id_cell(front_id)
    r = Vec2f(jx, jy) - o
    if norm(r) == 0
      p = 10*r + 0.5*i*Vec2f(0, 1) #+ 3.0*rand()*Vec2f(1, 0)
    else
      rhat = normalize(r); rhatperp = Vec2f(rhat[2],-rhat[1])
      p = 10*r + 0.5*i*rhat #+ 3.0*rand()*rhatperp
    end
    fix = ""
    cell, segid, cents = front_id_strs(front_id)
    label = repr("$cell\n$segid\n$cents\n($l)")
    println(io, "  $front_id [label=$label, pos=\"$(p[1]),$(p[2])$fix\", fillcolor=\"$(colors[l+1])44\"];")
  end
  for (src, dst, d) = edges_same
    color = "black"
    if (src, dst) in edges_broken || (dst, src) in edges_broken
      # continue
      color = "red"
    end
    sjy, sjx, sjz = front_id_cell(src)
    djy, djx, djz = front_id_cell(dst)
    r = Vec2f(sjx+djx, sjy+djy)/2f0 - o
    w = d < Inf32 ? round(Int, d) : 9000
    # println(io, "  $src -> $dst [label=$w, color=$color, dir=none, weight=$(20/norm(r)), len=$(5*norm(r))];")
    println(io, "  $src -> $dst [label=$w, color=$color, dir=none, len=3];")
  end
  for (src, dst, d) = edges_less
    len = "len=6, "
    color = "cyan"
    if (src, dst) in edges_wind
      # len = "len=150, "
      len = "len=3, "
      color = "magenta"
    end
    if (src, dst) in edges_broken
      # continue
      color = "red"
      if (src, dst) in edges_wind
        color = "orange"
      end
    end
    label = d > 1 ? "label=$d, " : ""
    println(io, "  $src -> $dst [$(label)$(len)color=$color];")
  end
  println(io, "}")
end

select_boundary_points_jx(pclouds::Vector{PointCloud}, jx::Int) =
  map(pc -> select_boundary_points_jx(pc, jx), pclouds)
select_boundary_points_jy(pclouds::Vector{PointCloud}, jy::Int) =
  map(pc -> select_boundary_points_jy(pc, jy), pclouds)
select_boundary_points_jz(pclouds::Vector{PointCloud}, jz::Int) =
  map(pc -> select_boundary_points_jz(pc, jz), pclouds)

# This must be set to a little over the superpixel spacing (10), to leave the
# single set of points closest to the boundary. There's a small asymmetry.
const boundary_margin = 12.5f0
select_boundary_points_jx(pc::PointCloud, jx::Int) = begin
  points = []; normals = []
  for i = 1:length(pc.points)
    p = pc.points[i]; n = pc.normals[i]
    if abs(p[1] - 500f0*jx) < boundary_margin
      push!(points, p); push!(normals, n)
    end
  end
  PointCloud(pc.id, points, normals)
end
select_boundary_points_jy(pc::PointCloud, jy::Int) = begin
  points = []; normals = []
  for i = 1:length(pc.points)
    p = pc.points[i]; n = pc.normals[i]
    if abs(p[2] - 500f0*jy) < boundary_margin
      push!(points, p); push!(normals, n)
    end
  end
  PointCloud(pc.id, points, normals)
end
select_boundary_points_jz(pc::PointCloud, jz::Int) = begin
  points = []; normals = []
  for i = 1:length(pc.points)
    p = pc.points[i]; n = pc.normals[i]
    if abs(p[3] - 500f0*jz) < boundary_margin
      push!(points, p); push!(normals, n)
    end
  end
  PointCloud(pc.id, points, normals)
end

# Checking both directions yields similar results. Visually, in some cases it
# seems to help isolated components be added to the majority component, which
# probably means a whole cell was reversed and this solved it. However there's
# one jz group where it results in a big block of multiple turns not being
# properly split into turns. This might be because labelgen can produce cells
# with a mix of orientations, so they aren't right backwards or forwards. Cells
# containing the umbilicus will be like this, for instance.
# TODO: A more general edit distance may be able to handle this case.
# Until then, assuming the direction from the chunks seems best.
# match_boundary(pclouds::Vector{PointCloud}, qclouds::Vector{PointCloud}, threshold::Float32) = begin
#   m_straight = match_boundary_direct(pclouds, qclouds, threshold)
#   reverse!(pclouds)
#   m_flipped = match_boundary_direct(pclouds, qclouds, threshold)
#   reverse!(pclouds)
#   if length(m_straight) >= length(m_flipped)
#     m_straight
#   else
#     P = length(pclouds)
#     for i = 1:length(m_flipped)
#       ip, iq, d = m_flipped[i]
#       m_flipped[i] = (P-ip+1, iq, d)
#     end
#     m_flipped
#   end
# end

N_mem = zeros(Float32, 100, 100)
D_mem = zeros(Float32, 100, 100)

match_boundary(pclouds::Vector{PointCloud}, qclouds::Vector{PointCloud}, threshold::Float32) = begin
  matches = []
  if isempty(pclouds) || isempty(qclouds)
    return matches
  end
  P = length(pclouds); Q = length(qclouds)
  # N = zeros(Float32, P+1, Q+1) # DP table for match count.
  # D = zeros(Float32, P, Q)
  N = view(N_mem, 1:P+1, 1:Q+1) # DP table for match count.
  D = view(D_mem, 1:P, 1:Q)
  for iq = 1:Q
    D[1, iq] = d = boundary_matching_distance(pclouds[1], qclouds[iq])
    if d < threshold
      N[1, iq] = 100*threshold - d
    else
      N[1, iq] = 0f0
    end
  end
  for ip = 2:P+1
    if ip <= P
      D[ip, 1] = d = boundary_matching_distance(pclouds[ip], qclouds[1])
      if d < threshold
        N[ip, 1] = 100*threshold - d
      else
        N[ip, 1] = 0f0
      end
    end
    for iq = 2:Q+1
      match = 0f0
      if iq <= Q && ip <= P
        D[ip, iq] = d = boundary_matching_distance(pclouds[ip], qclouds[iq])
        if d < threshold
          match = 100*threshold - d
        end
      end
      N[ip, iq] = max(N[ip-1, iq-1] + match, N[ip, iq-1], N[ip-1, iq])
    end
  end
  ip = P+1; iq = Q+1
  while ip > 1 && iq > 1
    from = argmax((N[ip-1, iq-1], N[ip, iq-1], N[ip-1, iq]))
    if from == 1
      if D[ip-1, iq-1] < threshold
        push!(matches, (ip-1, iq-1, D[ip-1, iq-1]))
      end
      ip -= 1; iq -= 1
    elseif from == 2
      iq -= 1
    else
      ip -= 1
    end
  end
  matches
end

# match_boundary(pclouds::Vector{PointCloud}, qclouds::Vector{PointCloud}, threshold::Float32) = begin
#   # This matches the fist pair seen under the threshold. This will result in
#   # skipping overlapping/duplicate sheets. Make this more robust so it matches
#   # the least distant pairs instead of picking the first that do.
#   matches = []
#   ip = 1; iq = 1
#   while ip <= length(pclouds) && iq <= length(qclouds)
#     if isempty(pclouds[ip])  ip += 1; continue;  end
#     if isempty(qclouds[iq])  iq += 1; continue;  end
#     d = boundary_matching_distance(pclouds[ip], qclouds[iq])
#     if d < threshold
#       push!(matches, (ip, iq, d))
#       ip += 1
#       iq += 1
#     else
#       if iq == length(qclouds)   ip += 1; continue;  end
#       if isempty(pclouds[ip])    ip += 1; continue;  end
#       if isempty(qclouds[iq+1])  iq += 1; continue;  end
#       dqnext = boundary_matching_distance(pclouds[ip], qclouds[iq+1])
#       if dqnext < d
#         iq += 1
#       else
#         ip += 1
#       end
#     end
#   end
#   matches
# end

boundary_matching_distance(ps::PointCloud, qs::PointCloud) = begin
  if isempty(ps) || isempty(qs)
    return Inf32
  end
  # TODO: We should be able to replace this dumb O(n*m) algorithm with something
  # faster that works just as well for our purpopses. Approximate distances ok.
  dp = boundary_matching_distance_lopsided(ps, qs)
  dq = boundary_matching_distance_lopsided(qs, ps)
  (dp + dq)/2f0
end
boundary_matching_distance_lopsided(ps::PointCloud, qs::PointCloud) = begin
  d_sum = 0f0
  plen = length(ps.points); qlen = length(qs.points)
  for i = 1:plen
    p = ps.points[i]; pn = ps.normals[i]
    d_min = Inf32
    for j = 1:qlen
      q = qs.points[j]; qn = qs.normals[j]
      if abs(dot(pn, qn)) > 0.7f0 # The normals have to be aligned.
        n = normalize(pn + qn)
        if dot(pn, qn) < 0f0
          n = normalize(pn - qn)
        end
        d = abs(dot(p - q, n))
        if d < d_min
          d_min = d
        end
      end
    end
    d_sum += d_min
  end
  d_sum / plen
end

# threshold = 22.5f0
# boundary_matching_distance_lopsided(ps::PointCloud, qs::PointCloud) = begin
#   dsq_sum = 0f0
#   for p = ps.points
#     dsq_min = Inf32
#     for q = qs.points
#       dsq = norm_squared(p - q)
#       if dsq < dsq_min
#         dsq_min = dsq
#       end
#     end
#     dsq_sum += dsq_min
#   end
#   sqrt(dsq_sum / length(ps.points))
# end

