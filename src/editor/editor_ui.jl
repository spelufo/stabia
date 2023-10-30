do_frame(ed::Editor) = begin
  ed.frame += 1

  do_frame_reload_shaders(ed)
  do_frame_handle_keys(ed)

  do_dockspace(ed)
  do_menu_bar(ed)
  do_info(ed)
  do_controls(ed)

  do_view_cross(ed, ed.view_cross)
  do_view_top(ed, ed.view_top)
  do_view_3d(ed, ed.view_3d)
  nothing
end

do_frame_reload_shaders(ed::Editor) = begin
  if ed.frame % 60 == 0
    reload!(ed.view_3d.shader)
    reload!(ed.view_top.shader)
    reload!(ed.view_cross.shader)
  end
end

do_frame_handle_keys(ed::Editor) = begin
  # TODO: Modifiers bug.
  for (kb, f) = KEYMAP
    if kb.continuous && kb.mods == 0
      if CImGui.IsKeyDown(kb.key) # && CImGui.IsKeyDown(kb.mods) # TODO: mods
        f()
      end
    end
  end
end

do_axis_planes(ed::Editor, shader::Shader) = begin
  c = ed.cursor.p
  q = ed.cursor.q
  l = ed.cell.L
  ed.draw_axis_xy[] && draw(StaticQuadMesh(c, rotate(Ez, q), rotate(Ey, q), l, l), shader)
  ed.draw_axis_yz[] && draw(StaticQuadMesh(c, rotate(Ex, q), rotate(Ez, q), l, l), shader)
  ed.draw_axis_zx[] && draw(StaticQuadMesh(c, rotate(Ey, q), rotate(Ez, q), l, l), shader)
  nothing
end

# TODO: Currently unused.
update_cursor_camera!(ed::Editor) = begin
  f = ydir(ed.cursor)
  ed.view_cross.camera.p = ed.cursor.p + 2f0*f
  ed.view_cross.camera.n = -f
  nothing
end




do_dockspace(ed::Editor) =
  LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL)

do_menu_bar(ed::Editor) = begin
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

do_info(ed::Editor) = begin
  CImGui.Begin("Info")
  CImGui.Text("Cell: $(ed.cell.j)")
  CImGui.Text("GPU: $(the_gpu_info.renderer_string)")
  CImGui.Text("GPU max texture buffer size: $(the_gpu_info.max_texture_buffer_size / 1024^2) MB")
  CImGui.End()
end

do_controls(ed::Editor) = begin
  CImGui.Begin("Controls")
  cp = ed.cursor.p
  cf = ydir(ed.cursor)

  # if CImGui.Button("Transition")

  CImGui.Separator()
  CImGui.Text("Cursor")
  CImGui.Text("Cursor p: $(cp[1]), $(cp[2]), $(cp[3])")
  CImGui.Text("Cursor y: $(cf[1]), $(cf[2]), $(cf[3])")

  CImGui.Separator()
  do_perps_controls(ed.perps)

  CImGui.Separator()
  CImGui.Text("Axis Planes")
  CImGui.Checkbox("XY", ed.draw_axis_xy)
  CImGui.Checkbox("YZ", ed.draw_axis_yz)
  CImGui.Checkbox("ZX", ed.draw_axis_zx)

  CImGui.Separator()
  CImGui.Checkbox("Holes Meshes", ed.draw_holes)

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



# Key bindings #################################################################

struct KeyBinding
  key::Int32
  mods::Int32
  continuous::Bool
end

KeyBinding(key, mods) =
  KeyBinding(key, mods, false)

const KeyMap = Dict{KeyBinding, Function}

Δc = 0.015f0

KEYMAP = KeyMap(
  KeyBinding(GLFW_KEY_W, 0, true)        => () -> move_cursor!(the_editor, 0f0, +Δc, 0f0),
  KeyBinding(GLFW_KEY_S, 0, true)        => () -> move_cursor!(the_editor, 0f0, -Δc, 0f0),
  KeyBinding(GLFW_KEY_A, 0, true)        => () -> move_cursor!(the_editor, -Δc, 0f0, 0f0),
  KeyBinding(GLFW_KEY_D, 0, true)        => () -> move_cursor!(the_editor, +Δc, 0f0, 0f0),
  KeyBinding(GLFW_KEY_F, 0, true)        => () -> move_cursor!(the_editor, 0f0, 0f0, -Δc),
  KeyBinding(GLFW_KEY_R, 0, true)        => () -> move_cursor!(the_editor, 0f0, 0f0, +Δc),
  KeyBinding(GLFW_KEY_Q, 0, true)        => () -> rotate_cursor!(the_editor, -Δc),
  KeyBinding(GLFW_KEY_E, 0, true)        => () -> rotate_cursor!(the_editor, +Δc),

  KeyBinding(GLFW_KEY_G+1, 0, true)      => () -> rotate_3d_view!(the_editor, -Δc, 0f0),
  KeyBinding(GLFW_KEY_L, 0, true)        => () -> rotate_3d_view!(the_editor, +Δc, 0f0),
  KeyBinding(GLFW_KEY_J, 0, true)        => () -> rotate_3d_view!(the_editor, 0f0, -Δc),
  KeyBinding(GLFW_KEY_K, 0, true)        => () -> rotate_3d_view!(the_editor, 0f0, +Δc),

  KeyBinding(GLFW_KEY_W, GLFW_MOD_ALT)   => () -> toggle_wireframe!(the_editor),
  KeyBinding(GLFW_KEY_0, 0)              => () -> the_editor.style = 0,
  KeyBinding(GLFW_KEY_1, 0)              => () -> the_editor.style = 1,
  KeyBinding(GLFW_KEY_2, 0)              => () -> the_editor.style = 2,
  KeyBinding(GLFW_KEY_3, 0)              => () -> the_editor.style = 3,
  KeyBinding(GLFW_KEY_4, 0)              => () -> the_editor.style = 4,
  KeyBinding(GLFW_KEY_5, 0)              => () -> the_editor.style = 5,
)

on_key!(ed::Editor, window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid = begin
  if action == GLFW_PRESS || action == GLFW_REPEAT
    f = get(KEYMAP, KeyBinding(key, mods, false), nothing)
    !isnothing(f) && f()
  end
  nothing
end