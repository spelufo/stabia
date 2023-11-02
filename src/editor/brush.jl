
do_brush(ed::Editor, view::Viewport, brush::Brush) = begin
  if !CImGui.IsWindowHovered() || brush.state != :editing || isnothing(ed.perps.focus)
    return
  end

  if CImGui.IsMouseDown(0)
    mpos = CImGui.GetMousePos() - view.pos
    mray = mouse_ray(view, mpos)
    hit, λ = raycast(mray, perp_plane(ed.perps.focus))

    # Mouse just pressed down, start tracing.
    if CImGui.IsMouseClicked(0)
      if λ >= 0
        ed.brush.trace = Vec3f[hit]
      end

    # Mouse down, tracing.
    elseif length(brush.trace) > 0
      min_distance_between_points = cell_mm(ed.scan)/100f0
      if λ >= 0 && norm(ed.brush.trace[end] - hit) > min_distance_between_points
        push!(ed.brush.trace, hit)
      end
    end
  end

  # Mouse released, end trace.
  if CImGui.IsMouseReleased(0)
    push!(ed.brush.traces, ed.brush.trace)
  end
end


draw_brush_traces(ed::Editor, view::Viewport) = begin
  if !isnothing(ed.brush.trace)
    draw(GLLine(ed.brush.trace), view.shader)
  end
  for trace = ed.brush.traces
    draw(GLLine(trace), view.shader)
  end
end
