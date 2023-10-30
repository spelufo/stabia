################################################################################

perp_n(perp::Perp) =
  Vec3f(-sin(perp.θ), cos(perp.θ), 0f0)

perp_u(perp::Perp) =
  Vec3f(cos(perp.θ), sin(perp.θ), 0f0)

GLMesh(perp::Perp, p0::Vec3f, p1::Vec3f) = begin
  @assert all(p0 .<= perp.p .<= p1) "out of bounds: expected $p0 <= $(perp.p) <= $p1"
  a = Plane(p0,  Ex)
  b = Plane(p0,  Ey)
  c = Plane(p1, -Ex)
  d = Plane(p1, -Ey)
  r = Ray(perp.p,  perp_u(perp))
  pos_hit, pos_λ, neg_hit, neg_λ = raycast(r, Plane[a, b, c, d])

  GLQuadMesh(
    Vec3f(pos_hit[1], pos_hit[2], p0[3]),
    Vec3f(pos_hit[1], pos_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p1[3]),
    Vec3f(neg_hit[1], neg_hit[2], p0[3]),
  )
end

interpolate(λ::Float32, perp1::Perp, perp2::Perp) =
  Perp(λ*perp1.p + (1f0-λ)*perp2.p, λ*perp1.θ + (1f0-λ)*perp2.θ)


################################################################################

draw_perps(perps::Perps, view::Viewport) = begin
  for mesh = perps.meshes
    draw(mesh, view.shader)
  end
end

do_perps_add(ed::Editor, view::Viewport) = begin
  perps = ed.perps
  mpos = CImGui.GetMousePos() - view.pos
  if CImGui.IsWindowHovered()
    # Start adding on click down.
    if CImGui.IsMouseClicked(0) && !CImGui.IsMouseDragging()
      if isnothing(perps.add_start)
        mr = mouse_ray(view, mpos)
        hit, λ = raycast(mr, Plane(ed.cursor.p, Ez))
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
          push!(perps.perps, perp)
          push!(perps.meshes, perps.add_mesh)
          perps.active = length(perps.perps)
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
    perps.perps = []
    perps.meshes = []
  end
  if CImGui.IsKeyPressed(GLFW_KEY_ESCAPE)
    perps.add_start = nothing
    perps.add_mesh = nothing
  end

  draw_perps(perps, view)
end

do_active_perp_view(perps::Perps, view::Viewport) = begin
  if 1 <= perps.active <= length(perps.perps)
    perp = perps.perps[perps.active]
    perp_mesh = perps.meshes[perps.active]
    n = perp_n(perp)
    view.camera.p = perp.p + 2f0*n
    view.camera.n = -n
    set_viewport!(view.camera, view.size.x, view.size.y)
    draw(perp_mesh, view.shader)
  end
end

do_perps_controls(perps::Perps) = begin
  CImGui.Text("Perps")
  for i = 1:length(perps.perps)
    if CImGui.Button("o##$i")
      perps.active = i
    end
    CImGui.SameLine(); if CImGui.Button("^##$i") && i > 1
      perps.perps[i-1], perps.perps[i] = perps.perps[i], perps.perps[i-1]
      perps.meshes[i-1], perps.meshes[i] = perps.meshes[i], perps.meshes[i-1]
    end
    CImGui.SameLine(); if CImGui.Button("v##$i") && i < length(perps.perps)
      perps.perps[i+1], perps.perps[i] = perps.perps[i], perps.perps[i+1]
      perps.meshes[i+1], perps.meshes[i] = perps.meshes[i], perps.meshes[i+1]
    end
    CImGui.SameLine(); if CImGui.Button("×##$i")
      deleteat!(perps.perps, i)
      deleteat!(perps.meshes, i)
    end
    CImGui.SameLine(); CImGui.Text("$i")
  end
end
