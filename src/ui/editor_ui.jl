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
