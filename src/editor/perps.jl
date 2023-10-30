

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



do_perps(ed::Editor, view::Viewport) = begin
  for mesh = ed.perp_meshes
    draw(mesh, view.shader)
  end
end

do_perps_add(ed::Editor, view::Viewport) = begin
  mpos = CImGui.GetMousePos() - view.pos
  if CImGui.IsWindowHovered()
    # Start adding on click down.
    if CImGui.IsMouseClicked(0) && !CImGui.IsMouseDragging()
      if isnothing(ed.perp_add_start)
        mr = mouse_ray(view, mpos)
        hit, λ = raycast(mr, Plane(ed.cursor.p, Ez))
        if λ >= 0 && all(ed.cell.p .<= hit .<= ed.cell.p .+ ed.cell.L)
          ed.perp_add_start = hit
        end
      end
    end
    # Add on click release.
    if !isnothing(ed.perp_add_start)
      hit, λ = raycast(mouse_ray(view, mpos), Plane(ed.cursor.p, Ez))
      if λ > 0
        perp = Perp(ed.perp_add_start, hit)
        ed.perp_add_mesh = GLMesh(perp, ed.cell.p, ed.cell.p .+ ed.cell.L)
        if CImGui.IsMouseReleased(0)
          # TODO: check it is the same view the click started. Small bug.
          push!(ed.perps, perp)
          push!(ed.perp_meshes, ed.perp_add_mesh)
          ed.perp_active = length(ed.perps)
          ed.perp_add_start = nothing
          ed.perp_add_mesh = nothing
        end
      end
    end
  end
  # Draw preview if adding
  if !isnothing(ed.perp_add_mesh)
    draw(ed.perp_add_mesh, view.shader)
  end
  if CImGui.IsKeyPressed(GLFW_KEY_DELETE)
    ed.perps = []
    ed.perp_meshes = []
  end
  if CImGui.IsKeyPressed(GLFW_KEY_ESCAPE)
    ed.perp_add_start = nothing
    ed.perp_add_mesh = nothing
  end
end
