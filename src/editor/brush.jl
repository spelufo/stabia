
do_brush(ed::Editor, view::Viewport, brush::Brush) = begin
  if !CImGui.IsWindowHovered() || brush.state != :editing || isnothing(ed.perps.focus)
    return
  end

  min_distance_between_points = cell_mm(ed.scan)/100f0
  trace_offset_from_plane = cell_mm(ed.scan)/1000f0

  if CImGui.IsMouseDown(0)
    mpos = CImGui.GetMousePos() - view.pos
    mray = mouse_ray(view, mpos)
    hit, λ = raycast(mray, perp_plane(ed.perps.focus))
    # TODO: I would have expected needing -= here instead of +=. Why +=?
    hit += trace_offset_from_plane*normalize(mray.v) # hack to avoid z-fighting

    # Mouse just pressed down, start tracing.
    if CImGui.IsMouseClicked(0)
      if λ >= 0
        brush.trace = Vec3f[hit]
      end

    # Mouse down, tracing.
    elseif length(brush.trace) > 0 && length(brush.trace) > 0
      if λ >= 0 && norm(brush.trace[end] - hit) > min_distance_between_points
        push!(brush.trace, hit)
      end
    end
  end

  # Mouse released, end trace.
  if CImGui.IsMouseReleased(0)
    push!(brush.traces, brush.trace)
    brush.trace = nothing
  end
end


draw_brush_traces(ed::Editor, view::Viewport, brush::Brush) = begin
  if !isnothing(brush.trace)
    glUniform1i(glGetUniformLocation(view.shader, "style"), 9)
    draw(GLLine(brush.trace), view.shader)
  end
  for trace = brush.traces
    glUniform1i(glGetUniformLocation(view.shader, "style"), 9)
    draw(GLLine(trace), view.shader)
  end
end
