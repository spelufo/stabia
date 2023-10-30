
toggle_wireframe!(ed::Editor) = begin
  ed.view_3d.wireframe = !ed.view_3d.wireframe
  ed.view_top.wireframe = !ed.view_top.wireframe
  ed.view_cross.wireframe = !ed.view_cross.wireframe
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


rotate_cursor!(ed::Editor, dθ::Float32) = begin
  ed.cursor = rotate(ed.cursor, Ez, dθ)
end

