draw_dockspace(ed::Editor) =
  LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)

draw_menu_bar(ed::Editor) = begin
  CImGui.BeginMainMenuBar()
  if CImGui.BeginMenu("File")
    CImGui.MenuItem("New")
    CImGui.MenuItem("Open")
    CImGui.MenuItem("Save")
    CImGui.MenuItem("Save As...")
    CImGui.EndMenu()
  end
  if CImGui.BeginMenu("Edit")
    CImGui.MenuItem("Edit")
    CImGui.EndMenu()
  end
  if CImGui.BeginMenu("Help")
    CImGui.MenuItem("Help")
    CImGui.EndMenu()
  end
  CImGui.EndMainMenuBar()
end

draw_info(ed::Editor) = begin
  CImGui.Begin("Info")
  CImGui.Text("Cell: $(ed.cell.j)")
  CImGui.Text("GPU: $(the_gpu_info.renderer_string)")
  CImGui.Text("GPU max texture buffer size: $(the_gpu_info.max_texture_buffer_size / 1024^2) MB")
  CImGui.End()
end

draw_controls(ed::Editor) = begin
  CImGui.Begin("Controls")
  # angle = Ref(180f0 * acos(ed.cursor.n[1]) / π)
  # DragFloat("Cut angle", angle, 1f0, -180f0, 180f0)
  # θ = π * angle[] / 180f0
  # update_cursor!(ed, ed.cursor.p, θ)
  # update_cursor_camera!(ed)

  cp = ed.cursor.p
  cf = ydir(ed.cursor)

  CImGui.Text("Cursor p: $(cp[1]), $(cp[2]), $(cp[3])")
  CImGui.Text("Cursor y: $(cf[1]), $(cf[2]), $(cf[3])")
  CImGui.Checkbox("Axis Planes", ed.draw_axis_planes)
  CImGui.End()
end
