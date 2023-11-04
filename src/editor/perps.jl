################################################################################

perp_n(perp::Perp) =
  Vec3f(-sin(perp.θ), cos(perp.θ), 0f0)

perp_u(perp::Perp) =
  Vec3f(cos(perp.θ), sin(perp.θ), 0f0)

perp_plane(perp::Perp) =
  Plane(perp.p, perp_n(perp))

perp_box_bounds(perp::Perp, p0::Vec3f, p1::Vec3f) = begin
  a = Plane(p0,  Ex)
  b = Plane(p0,  Ey)
  c = Plane(p1, -Ex)
  d = Plane(p1, -Ey)
  r = Ray(perp.p,  perp_u(perp))
  if !all(p0 .<= perp.p .<= p1)
    pos_hit, pos_λ, neg_hit, neg_λ = raycast(r, Plane[a, b, c, d])
    if isfinite(pos_λ)
      r = Ray(pos_hit + 0.001*r.v, r.v)
    elseif isfinite(neg_λ)
      r = Ray(pos_neg - 0.001*r.v, r.v)
    else
      @assert false "perp doesn't intersect with p0-p1 box"
    end
  end
  pos_hit, pos_λ, neg_hit, neg_λ = raycast(r, Plane[a, b, c, d])

  (
    Vec3f(pos_hit[1], pos_hit[2], p0[3]),
    Vec3f(pos_hit[1], pos_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p0[3]),
  )
end

GLMesh(perp::Perp, p0::Vec3f, p1::Vec3f) =
  GLQuadMesh(perp_box_bounds(perp, p0, p1)...)

perps_walk(perps::Vector{Perp}, p0::Vec3f) = begin
  k = length(perps)
  @assert k >= 2 "At least two perps required."
  path = Vec3f[p0]
  nlast = perp_n(perps[1])
  @assert dot(p0 - perps[1].p, nlast) ≈ 0 "p0 must be in plane perp[1]."
  walk = zeros(Float32, 3*(k-1), 3)
  for i = 2:k
    perp = perps[i]
    n = perp_n(perp)
    γ, p = curve_normal_to_planes(path[end], nlast, perp.p, n)
    walk[3*(i-2)+1 : 3*(i-2)+3, :] = γ
    push!(path, p)
    nlast = n
  end
  walk
end

perps_walk_eval(walk::Matrix{Float32}, t::Float32) = begin
  i = clamp(floor(Int, t), 0, div(size(walk, 1), 3)-1)
  γ = @view walk[3i+1:3i+3,:]
  t -= Float32(i)
  Vec3f(γ*Vec3f(t^2, t, 1)), Vec3f(γ*Vec3f(2f0*t, 1f0, 0f0))
end

perps_walk_eval_perp(walk::Matrix{Float32}, t::Float32) = begin
  p, n = perps_walk_eval(walk, t)
  Perp(p, angle(Ey, n))
end

perps_walk_length(perps::Perps) =
  size(perps.walk, 1)/3f0


# UI ###########################################################################


draw_perps(ed::Editor, view::Viewport) = begin
  perps = ed.perps
  if perps.state != :editing
    if !isnothing(perps.focus_mesh)
      draw(perps.focus_mesh, view.shader)
    end
  else
    for mesh = perps.meshes
      draw(mesh, view.shader)
    end
  end
end


draw_perps_cross_view(ed::Editor, view::Viewport) = begin
  perps = ed.perps
  if perps.state != :editing && !isnothing(perps.focus)
    perp = perps.focus
    n = perp_n(perp)
    view.camera.p = perp.p + 2f0*n
    view.camera.n = -n
    draw(perps.focus_mesh, view.shader)
  end
end

update_perps(ed::Editor, perps::Perps) = begin
  if perps.state != :editing
    perps.t += perps.dt
    if perps.t > perps_walk_length(perps)
      perps.t = 0f0
    elseif perps.t < 0f0
      perps.t = perps_walk_length(perps)
    end

    perp = perps_walk_eval_perp(perps.walk, perps.t)
    perps.focus = perp
    perps.focus_mesh = GLMesh(perp, ed.cell.p, ed.cell.p .+ ed.cell.L)
  end
end

do_perps_controls(ed::Editor, perps::Perps) = begin
  CImGui.Text("Perps")
  if perps.state != :editing
    if CImGui.Button("Edit")  perps.state = :editing  end
  else
    guides = perps.guides
    if length(guides) < 2
      CImGui.Text("Click on 3d view to add guide perps.")
    else
      if CImGui.Button("Done")
        perps.state = :stable
        perps.walk = perps_walk(guides, guides[1].p)
        if size(perps.slices, 3) == 0
          println("Building perps slices, this will take a minute...")
          @time build_perp_slices!(ed.cell, perps)
        end
        if size(perps.flow, 3) == 0
          println("Building perps flow, this will take a minute...")
          @time build_perp_flow!(ed.cell, perps)
        end
      end
    end
  end
  if perps.state != :editing
    tref = Ref(perps.t)
    CImGui.SliderFloat("t", tref, 0.0f0, perps_walk_length(perps))
    perps.t = tref[]

    speed = Ref(60f0*perps.dt)
    CImGui.SliderFloat("Speed", speed, -1f0, 1f0)
    perps.dt = speed[]/60f0

    if CImGui.Button("Stop")  perps.dt = 0f0  end
    if CImGui.Button("Play")  perps.dt = 0.05f0/60f0  end
    if CImGui.Button("Back")  perps.dt = -0.05f0/60f0  end
  else
    for i = 1:length(perps.guides)
      if CImGui.Button("^##$i") && i > 1
        perps.guides[i-1], perps.guides[i] = perps.guides[i], perps.guides[i-1]
        perps.meshes[i-1], perps.meshes[i] = perps.meshes[i], perps.meshes[i-1]
      end
      CImGui.SameLine(); if CImGui.Button("v##$i") && i < length(perps.guides)
        perps.guides[i+1], perps.guides[i] = perps.guides[i], perps.guides[i+1]
        perps.meshes[i+1], perps.meshes[i] = perps.meshes[i], perps.meshes[i+1]
      end
      CImGui.SameLine(); if CImGui.Button("×##$i")
        deleteat!(perps.guides, i)
        deleteat!(perps.meshes, i)
      end
      CImGui.SameLine(); CImGui.Text("$i")
    end
  end
end

do_perps_add(ed::Editor, view::Viewport) = begin
  perps = ed.perps
  perps.state == :editing || return nothing
  mpos = CImGui.GetMousePos() - view.pos
  if CImGui.IsWindowHovered()
    # Start adding on click down.
    if CImGui.IsMouseClicked(0) && !CImGui.IsMouseDragging()
      if isnothing(perps.add_start)
        mray = mouse_ray(view, mpos)
        hit, λ = raycast(mray, Plane(ed.cursor.p, Ez))
        if λ >= 0 && all(ed.cell.p .<= hit .<= ed.cell.p .+ ed.cell.L)
          perps.add_start = hit
        end
      end
    end
    # Add on click release.
    if !isnothing(perps.add_start)
      hit, λ = raycast(mouse_ray(view, mpos), Plane(ed.cursor.p, Ez))
      if λ > 0
        perp = Perp(perps.add_start, hit)
        perps.add_mesh = GLMesh(perp, ed.cell.p, ed.cell.p .+ ed.cell.L)
        if CImGui.IsMouseReleased(0)
          # TODO: check it is the same view the click started. Small bug.
          push!(perps.guides, perp)
          push!(perps.meshes, perps.add_mesh)
          perps.add_start = nothing
          perps.add_mesh = nothing
        end
      end
    end
  end
  # Draw preview if adding
  if !isnothing(perps.add_mesh)
    draw(perps.add_mesh, view.shader)
  end
  if CImGui.IsKeyPressed(GLFW_KEY_DELETE)
    perps.guides = []
    perps.meshes = []
  end
  if CImGui.IsKeyPressed(GLFW_KEY_ESCAPE)
    perps.add_start = nothing
    perps.add_mesh = nothing
  end
end

