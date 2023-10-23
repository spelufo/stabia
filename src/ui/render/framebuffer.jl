
mutable struct Framebuffer
  width  :: Int
  height :: Int
  id     :: UInt32
  texid  :: UInt32
  rboid  :: UInt32
end

Framebuffer(width::Int, height::Int) = begin
  fb = Framebuffer(0, 0, 0, 0, 0)
  resize!(fb, width, height)
  fb
end

resize!(fb::Framebuffer, width::Int, height::Int) = begin
  if fb.id > 0 && width == fb.width && height == fb.height
    return nothing
  end

  # Delete if existing, we'll create new ones.
  if fb.id > 0  glDeleteFramebuffers(1, Ref(fb.id))  end
  if fb.texid > 0  glDeleteTextures(1, Ref(fb.texid))  end
  if fb.rboid > 0  glDeleteRenderbuffers(1, Ref(fb.rboid))  end

  fb.width = width
  fb.height = height

  fbid = Ref(UInt32(0))
  glGenFramebuffers(1, fbid)
  fb.id = fbid[]
  glBindFramebuffer(GL_FRAMEBUFFER, fb.id)

  # Color texture attachment.
  fbtexid = Ref(UInt32(0))
  glGenTextures(1, fbtexid)
  fb.texid = fbtexid[]
  glBindTexture(GL_TEXTURE_2D, fb.texid)
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, fb.width, fb.height, 0, GL_RGB, GL_UNSIGNED_BYTE, C_NULL) 
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glBindTexture(GL_TEXTURE_2D, 0)
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fb.texid, 0)

  # Depth and stencil render buffer attachment.
  fbrboid = Ref(UInt32(0))
  glGenRenderbuffers(1, fbrboid)
  fb.rboid = fbrboid[]
  glBindRenderbuffer(GL_RENDERBUFFER, fb.rboid) 
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height)
  glBindRenderbuffer(GL_RENDERBUFFER, 0)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, fb.rboid)

  @assert glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE  "framebuffer incomplete"

  # Bind the default framebuffer, unbinding the one we just created.
  glBindFramebuffer(GL_FRAMEBUFFER, 0)
  nothing
end
