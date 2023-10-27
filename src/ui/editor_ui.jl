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

  CImGui.Text("Cursor")
  CImGui.Text("Cursor p: $(cp[1]), $(cp[2]), $(cp[3])")
  CImGui.Text("Cursor y: $(cf[1]), $(cf[2]), $(cf[3])")

  CImGui.Separator()
  CImGui.Text("Axis Planes")
  CImGui.Checkbox("XY", ed.draw_axis_xy)
  CImGui.Checkbox("YZ", ed.draw_axis_yz)
  CImGui.Checkbox("ZX", ed.draw_axis_zx)

  CImGui.Separator()
  CImGui.Text("Normals Equipotential")
  if CImGui.Button("Initialize")
    cell = ed.cell
    p = ed.cursor.p
    ed.sheet, ed.sheet_update! = normal_equipotential_mesh_init(ed.scan, cell.j, cell.N, p)
  end

  if !isnothing(ed.sheet_update!)
    CImGui.SliderFloat("δ", ed.δ, ed.cell.L/500f0, ed.cell.L/10f0)
    CImGui.SliderFloat("k_s", ed.k_s, 0.1f0, 10f0)
    CImGui.SliderFloat("k_n", ed.k_n, 0.1f0, 10f0)
    if ed.equipot_running 
      ed.sheet_update!(ed.δ[], ed.k_s[], ed.k_n[], 1)
      if CImGui.Button("Stop")
        ed.equipot_running = false
      end
    else
      if CImGui.Button("Simulate")
        ed.equipot_running = true
      end
      if CImGui.Button("Step")
        ed.sheet_update!(ed.δ[], ed.k_s[], ed.k_n[], 5)
      end
    end
  end
  CImGui.End()
end
