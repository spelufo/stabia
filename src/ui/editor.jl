struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")


mutable struct EditorView
  name :: String
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
end

EditorView(name::String, camera::Camera) =
  EditorView(name, Framebuffer(), Shader("shader.glsl"), camera, false)


mutable struct Editor
  doc :: Document
  scan :: HerculaneumScan
  cell :: Cell

  mode :: EditorMode
  cursor :: Pose
  frame :: Int
  view_3d    :: Union{EditorView, Nothing}
  view_top   :: Union{EditorView, Nothing}
  view_cross :: Union{EditorView, Nothing}

  sheet
end

Editor(doc::Document) = begin
  # TODO: At some point we should be able to start the editor without
  # any loaded cells. For now, we load the cell at startup and make things easier
  # for all the downstream code.
  # cell = !isempty(doc.cells) && doc.cells[1] || nothing
  cell = doc.cells[1]
  load_textures(cell)
  ed = Editor(
    doc, doc.scan, cell,
    MODE_NORMAL,
    Pose(center(cell)), # cursor
    0, # frame
    nothing, nothing, nothing, # views
    nothing, # sheet
  )
  reset_views!(ed)
  ed
end

reset_views!(ed::Editor) = begin
  p = ed.cell.p
  c = center(ed.cell)
  L = ed.cell.L

  name = "3D View"
  ed.view_3d = EditorView(name, PerspectiveCamera(p + 2*L*Vec3f(1, 1, 0.7), p, Ez, 1))

  name = "Top View"
  n = 2f0 * L * Ez
  ed.view_top = EditorView(name, OrthographicCamera(c + n, -n, Ey, L, L))

  name = "Cross View"
  n = 2f0 * L * Ey
  ed.view_cross = EditorView(name, OrthographicCamera(c + n, -n, Ez, L, L))
end

editor_views(ed::Editor) =
  (ed.view_3d, ed.view_top, ed.view_cross)

update!(ed::Editor) = begin
  ed.frame += 1

  # reload shaders
  if ed.frame % 60 == 0
    for view = editor_views(ed)
      reload!(view.shader)
    end
  end

  # handle keys
  if ed.mode == MODE_NORMAL
    for (kb, f) = KEYMAP_NORMAL
      if kb.continuous && kb.mods == 0
        if CImGui.IsKeyDown(kb.key) # && CImGui.IsKeyDown(kb.mods) # TODO: mods
          f()
        end
      end
    end
  end

  nothing
end

draw(ed::Editor) = begin
  draw_dockspace(ed)
  draw_menu_bar(ed)
  draw_info(ed)

  CImGui.Begin("Controls")
    # angle = Ref(180f0 * acos(ed.cursor.n[1]) / π)
    # DragFloat("Cut angle", angle, 1f0, -180f0, 180f0)
    # θ = π * angle[] / 180f0

    # update_cursor!(ed, ed.cursor.p, θ)
    # update_cursor_camera!(ed)
  CImGui.End()

  # l = ed.cell.L/9f0
  # p0, p1 = cell_range_mm(ed.scan, 7, 7, 14)
  # p0 += ed.cell.L*Ez
  # p1 += ed.cell.L*Ez
  # gm = GridSheetFromRange(p0, p0 + ed.cell.L*Vec3f(1,1,0), Ex, l)

  # gm_cut = GridSheetFromCenter(ed.cursor.p, ed.cursor.n, Ez, l, 10, 10)

  draw_on_view!(ed, ed.view_3d) do shader, width, height
    draw_axis_planes(ed, shader)
  end
  draw_on_view!(ed, ed.view_cross) do shader, width, height
    draw_axis_planes(ed, shader)
  end
  draw_on_view!(ed, ed.view_top) do shader, width, height
    draw(StaticQuadMesh(center(ed.cell), Ez, Ey, ed.cell.L, ed.cell.L), shader)
  end
  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  nothing
end

draw_axis_planes(ed::Editor, shader::Shader) = begin
  c = center(ed.cell)
  l = ed.cell.L
  draw(StaticQuadMesh(c, Ez, Ey, l, l), shader)
  draw(StaticQuadMesh(c, Ey, Ez, l, l), shader)
  draw(StaticQuadMesh(c, Ex, Ez, l, l), shader)
  nothing
end

update_cursor_camera!(ed::Editor) = begin
  f = front(ed.cursor)
  ed.view_cross.camera.p = ed.cursor.p + 2f0*f
  ed.view_cross.camera.n = -f
  nothing
end

toggle_wireframe!(ed::Editor) = begin
  ed.view_3d.wireframe = !ed.view_3d.wireframe
  ed.view_top.wireframe = !ed.view_top.wireframe
  ed.view_cross.wireframe = !ed.view_cross.wireframe
end

rotate_cursor!(ed::Editor, dθ::Float32) = begin
  ed.cursor = rotate(ed.cursor, Ez, dθ)
end

move_cursor!(ed::Editor, dleft::Float32, dfwd::Float32) = begin
  ed.cursor = move(ed.cursor, dfwd * forward(ed.cursor) + dleft*left(ed.cursor))
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

KEYMAP_NORMAL = KeyMap(
  KeyBinding(GLFW_KEY_W, GLFW_MOD_ALT)   => () -> toggle_wireframe!(the_editor),

  KeyBinding(GLFW_KEY_S, 0, true)        => () -> move_cursor!(the_editor, 0f0, +0.01f0),
  KeyBinding(GLFW_KEY_W, 0, true)        => () -> move_cursor!(the_editor, 0f0, -0.01f0),
  KeyBinding(GLFW_KEY_A, 0, true)        => () -> move_cursor!(the_editor, -0.01f0, 0f0),
  KeyBinding(GLFW_KEY_D, 0, true)        => () -> move_cursor!(the_editor, +0.01f0, 0f0),
  KeyBinding(GLFW_KEY_Q, 0, true)        => () -> rotate_cursor!(the_editor, -0.01f0),
  KeyBinding(GLFW_KEY_E, 0, true)        => () -> rotate_cursor!(the_editor, +0.01f0),
)

on_key!(ed::Editor, window::Ptr{GLFWwindow}, key::Cint, scancode::Cint, action::Cint, mods::Cint)::Cvoid = begin
  if action == GLFW_PRESS || action == GLFW_REPEAT
    if ed.mode == MODE_NORMAL
      f = get(KEYMAP_NORMAL, KeyBinding(key, mods, false), nothing)
      !isnothing(f) && f()
    end
  end
  nothing
end

################################################################################

draw_on_view!(draw_fn::Function, ed::Editor, view::EditorView) = begin
  CImGui.Begin(view.name, C_NULL, ImGuiWindowFlags_NoScrollbar)
  view_size = CImGui.GetContentRegionAvail()
  width, height = floor(Int, view_size.x), floor(Int, view_size.y)
  if width > 0 && height > 0
    if resize!(view.fb, width, height)
      # println("Resized view framebuffer: $width × $height")
    end
    set_viewport!(view.camera, width, height)

    glBindFramebuffer(GL_FRAMEBUFFER, view.fb.id)
    glEnable(GL_DEPTH_TEST)
    glViewport(0, 0, width, height)
    glPolygonMode(GL_FRONT_AND_BACK, if view.wireframe GL_LINE else GL_FILL end)

    glClearColor(0.5, 0.5, 0.5, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    set_uniforms(view.camera, view.shader)
    set_uniforms(ed.cell, view.shader)
    set_textures(ed.cell, view.shader)

    # TODO: It seems like creating the VAOs in advance doesn't work but doing
    # so here while the FBO is bound does. Figure out why and how to handle it.
    draw_fn(view.shader, width, height)

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    CImGui.Image(Ptr{Cvoid}(UInt(view.fb.texid)), view_size, ImVec2(0, 1), ImVec2(1, 0))
  end
  CImGui.End()
end
