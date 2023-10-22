
mutable struct Editor
  cell :: Tuple{Int, Int, Int}
  shader :: Shader
  frame :: Int

  Editor() = new((7, 7, 14), Shader("shader.glsl"), 0)
end


init!(ed::Editor) = begin
  ed.cell
end

update!(ed::Editor) = begin
  if ed.frame % 60 == 0  reload!(ed.shader)  end
  ed.frame += 1
end

draw!(ed::Editor) = begin

end
