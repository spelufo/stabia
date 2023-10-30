
mutable struct Document
  scan :: HerculaneumScan
  cells :: Vector{Cell}
end

# Called by main(), for things that need to be reset when a new window/editor is
# created. It is an escape hatch, we should only need it if keeping transient
# state under Document, which should be shunned in favor os putting it in Editor.
reload!(doc::Document) = begin
  nothing
end


mutable struct Viewport
  name :: String
  pos :: ImVec2
  size :: ImVec2
  visible :: Bool
  fb :: Framebuffer
  shader :: Shader
  camera :: Camera
  wireframe :: Bool
  click_start :: Union{ImVec2, Nothing}
end

Viewport(name::String, camera::Camera) =
  Viewport(name, ImVec2(0, 0), ImVec2(0, 0), true, Framebuffer(),
    Shader("shader.glsl"), camera, false, nothing)

struct EditorMode
  name::String
end

const MODE_NORMAL = EditorMode("normal")

mutable struct Editor
  doc :: Document
  scan :: HerculaneumScan
  cell :: Cell

  mode :: EditorMode
  cursor :: Pose
  frame :: Int
  view_3d    :: Union{Viewport, Nothing}
  view_top   :: Union{Viewport, Nothing}
  view_cross :: Union{Viewport, Nothing}

  style :: Int32
  draw_axis_xy :: Ref{Bool}
  draw_axis_yz :: Ref{Bool}
  draw_axis_zx :: Ref{Bool}
  draw_holes :: Ref{Bool}

  perps :: Vector{Perp}
  perp_meshes :: Vector{GLMesh}
  perp_add_start :: Union{Vec3f, Nothing}
  perp_add_mesh :: Union{GLMesh, Nothing}
  perp_active :: Int

  # sheet sim
  sheet
  sheet_update! :: Union{Function, Nothing}
  δ :: Ref{Float32}
  k_s :: Ref{Float32}
  k_n :: Ref{Float32}
  equipot_running :: Bool
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
    Int32(1), # style
    Ref(true), Ref(false), Ref(false), # draw_axis_*
    Ref(false), # draw_holes

    # perps
    Perp[],
    GLMesh[],
    nothing,
    nothing,
    0,

    # sheet sim
    nothing, # sheet
    nothing, # sheet_update!
    Ref(cell.L/500f0), # δ
    Ref(1f0), # k_s
    Ref(1f0), # k_n
    false,
  )
  reset_views!(ed)
  ed
end

editor_views(ed::Editor) =
  (ed.view_3d, ed.view_top, ed.view_cross)

draw_frame(ed::Editor) = begin
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

  update_cursor_camera!(ed)

  draw_dockspace(ed)
  draw_menu_bar(ed)
  draw_info(ed)
  draw_controls(ed)

  draw_view_3d(ed, ed.view_3d)
  draw_view_top(ed, ed.view_top)
  draw_view_cross(ed, ed.view_cross)
  nothing
end

draw_axis_planes(ed::Editor, shader::Shader) = begin
  c = ed.cursor.p
  q = ed.cursor.q
  l = ed.cell.L
  ed.draw_axis_xy[] && draw(StaticQuadMesh(c, rotate(Ez, q), rotate(Ey, q), l, l), shader)
  ed.draw_axis_yz[] && draw(StaticQuadMesh(c, rotate(Ex, q), rotate(Ez, q), l, l), shader)
  ed.draw_axis_zx[] && draw(StaticQuadMesh(c, rotate(Ey, q), rotate(Ez, q), l, l), shader)
  nothing
end

update_cursor_camera!(ed::Editor) = begin
  f = ydir(ed.cursor)
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

move_cursor!(ed::Editor, dx::Float32, dy::Float32, dz::Float32) = begin
  ed.cursor = move(ed.cursor, dx*xdir(ed.cursor) + dy*ydir(ed.cursor) + dz*zdir(ed.cursor))
end

rotate_3d_view!(ed::Editor, dθ::Float32, dψ::Float32) = begin
  c = center(ed.cell)
  p = ed.view_3d.camera.pose.p
  q = ed.view_3d.camera.pose.q
  p = rotate(p - c, Ez, dθ) + c
  q = rotate(q, Ez, dθ)
  ed.view_3d.camera.pose = Pose(p, q)
  p = rotate(p - c, xdir(ed.view_3d.camera.pose), dψ) + c
  q = rotate(q, xdir(ed.view_3d.camera.pose), dψ)
  ed.view_3d.camera.pose = Pose(p, q)
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

KEYMAP_NORMAL = KeyMap(
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
    if ed.mode == MODE_NORMAL
      f = get(KEYMAP_NORMAL, KeyBinding(key, mods, false), nothing)
      !isnothing(f) && f()
    end
  end
  nothing
end
