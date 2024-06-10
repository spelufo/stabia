using MeshIO

save_ply(path, mesh; kwargs...) =
  MeshIO.save(File{format"PLY_BINARY"}(path), mesh; kwargs...)

ply_n_verts(path) = begin
  open(path) do file
    n_points = 0
    line = readline(file)
    while !startswith(line, "end_header")
      if startswith(line, "element vertex")
        n_points = parse(Int, split(line)[3])
        break
      end
      line = readline(file)
    end
    n_points
  end
end

@inline zpad(i::Int, ndigits::Int)::String =
  lpad(i, ndigits, "0")

@inline spad(i::Int, ndigits::Int)::String =
  lpad(i, ndigits, " ")

indexof(x::T, v::Vector{T}) where {T} = begin
  @inbounds for i = 1:length(v)
    if v[i] == x return i end
  end
  0
end

second(x) =
  x[2]

Base.reverse(g::T) where {T<:AbstractGraph} = begin
  grev = T(nv(g))
  for e = edges(g)
    add_edge!(grev, reverse(e))
  end
  grev
end

with_output_clipboard(f) =
  clipboard(with_output_string(f))

with_output_string(f) = begin
  buf = IOBuffer()
  f(buf)
  String(take!(buf))
end

print_blender_imports(paths; io::IO=stdout, params="global_scale=0.01, forward_axis='Y', up_axis='Z'") = begin
  println(io, "paths = $paths")
  println(io, """
for path in paths:
    if path.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path, $params)
    elif path.endswith(".stl"):
        bpy.ops.wm.stl_import(filepath=path, $params)
    elif path.endswith(".ply"):
        bpy.ops.wm.ply_import(filepath=path, $params)
    """)
end

colorhex(c) = begin
  r, g, b = round(UInt8, red(c)*255), round(UInt8, green(c)*255), round(UInt8, blue(c)*255)
  r, g, b = repr(r)[3:end], repr(g)[3:end], repr(b)[3:end]
  "#$(r)$(g)$(b)"
end
