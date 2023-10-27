
const SHADERS_DIR = "$(@__DIR__)/shaders"

mutable struct Shader
  id :: UInt32
  path :: String
  src :: String
  Shader() = new()
end

Shader(filename::String) = begin
  shader = Shader()
  shader.id = 0
  shader.src = ""
  shader.path = "$SHADERS_DIR/$filename"
  init!(shader)
  shader
end

gl_compile_shader(shader_id::UInt32, source::String) = begin
  glShaderSource(shader_id, 1, [source], [length(source)])
  glCompileShader(shader_id)
  status = Ref(Int32(0))
  glGetShaderiv(shader_id, GL_COMPILE_STATUS, status)
  if status[] != GL_TRUE
    err = Array{UInt8}(undef, 512)
    err_len = Ref(Int32(0))
    glGetShaderInfoLog(shader_id, sizeof(err), err_len, err)
    err[end] = 0
    error(unsafe_string(pointer(err)))
  end
  shader_id
end

init!(shader::Shader) = begin
  src = read(shader.path, String)
  if src == shader.src
    return false
  end
  shader.src = src
  m0 = match(r"^/{10,}$"m, shader.src)
  @assert !isnothing(m0) "GLSL file missing vertex shader"
  m1 = match(r"^/{10,}$"m, shader.src, m0.offset+length(m0.match))
  @assert !isnothing(m1) "GLSL file missing fragmen shader"
  shared_src = src[1:m0.offset-1]
  vertex_src = src[m0.offset:m1.offset-1]
  fragment_src = src[m1.offset:end]
  vertex_shader_src = string(shared_src, vertex_src)
  fragment_shader_src = string(shared_src, fragment_src)
  vertex_shader = UInt32(0)
  fragment_shader = UInt32(0)
  vertex_shader = gl_compile_shader(glCreateShader(GL_VERTEX_SHADER), vertex_shader_src)
  fragment_shader = gl_compile_shader(glCreateShader(GL_FRAGMENT_SHADER), fragment_shader_src)
  if shader.id > 0  glDeleteProgram(shader.id) end
  shader.id = glCreateProgram()
  glAttachShader(shader.id, vertex_shader)
  glAttachShader(shader.id, fragment_shader)
  glLinkProgram(shader.id)
  glUseProgram(shader.id)
  glDeleteShader(vertex_shader)
  glDeleteShader(fragment_shader)
  true
end

ModernGL.glGetUniformLocation(shader::Shader, name) =
  ModernGL.glGetUniformLocation(shader.id, name)

shader_failing = false

reload!(shader::Shader) = begin
  global shader_failing
  try
    shader_updated = init!(shader)
    if shader_updated
      shader_failing && println("Shader fixed.")
      shader_failing = false
    end
  catch err
    shader_failing = true
    println("Shader error:\n", err)
  end
end
