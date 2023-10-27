
struct GPUInfo
  renderer_string :: String
  max_texture_buffer_size :: Int32
end

GPUInfo() = begin
  max_texture_buffer_size = Ref{Int32}(0)
  glGetIntegerv(GL_MAX_TEXTURE_BUFFER_SIZE, max_texture_buffer_size)
  GPUInfo(
    unsafe_string(glGetString(GL_RENDERER)),
    max_texture_buffer_size[],
  )
end
