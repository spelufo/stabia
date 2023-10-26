using GLMakie
using FFTW

include("../src/Stabia.jl")

# if !@isdefined V
#   @time V = Float32.(load_grid_cell(scroll_1_54, 8, 5, 15))
#   @time M = load_cell_probabilities(scroll_1_54, 8, 5, 15)
#   v = V[1:100, 1:100, 1:100]
# end


# vis

streamplotfn(N::Array{Vec3f, 3}) = begin
  function f(x::Point3)
    convert(Point3, interpolate_trilinear(N, Vec3f(x[1], x[2], x[3])))
  end
  f
end

run_vis2(v::Array{Float32, 3}) = begin
  v = norm.(fftshift(fft(v)))

  mini, maxi = extrema(v)
  normed = Float32.((v .- mini) ./ (maxi - mini))

  fig = Figure(resolution=(1000, 450))
  # Make a colormap, with the first value being transparent
  colormap = to_colormap(:plasma)
  colormap[1] = RGBAf(0,0,0,0)
  # GLMakie.volume(fig[1, 1], normed, algorithm = :absorption, absorption=4f0, colormap=colormap, axis=(type=Axis3, title = "Absorption"))
  GLMakie.volume(fig[1, 1], normed, algorithm = :mip, colormap=colormap, axis=(type=Axis3, title="Maximum Intensity Projection"))
  
  fig
end

run_vis(v::Array{Float32, 3}) = begin
  f = norm.(fftshift(fft(v)))

  c = div(size(f, 1), 2) + 1
  f[c, c, c] = 0f0

  fig = Figure()
  ax1 = GLMakie.Axis(fig[1, 1])
  ax2 = GLMakie.Axis(fig[1, 2])
  image!(ax1, v[:, :, c])
  heatmap!(ax2, f[:, :, c])

  ax1 = GLMakie.Axis(fig[2, 1])
  ax2 = GLMakie.Axis(fig[2, 2])
  image!(ax1, v[:, c, :])
  heatmap!(ax2, f[:, c, :])

  ax1 = GLMakie.Axis(fig[3, 1])
  ax2 = GLMakie.Axis(fig[3, 2])
  image!(ax1, v[c, :, :])
  heatmap!(ax2, f[c, :, :])

  # sg = SliderGrid(
  #     fig[1, 2],
  #     (label = "Voltage", range = 0:0.1:10, format = "{:.1f}V", startvalue = 5.3),
  #     (label = "Current", range = 0:0.1:20, format = "{:.1f}A", startvalue = 10.2),
  #     (label = "Resistance", range = 0:0.1:30, format = "{:.1f}Ω", startvalue = 15.9),
  #     width = 350,
  #     tellheight = false)
  # sliderobservables = [s.value for s in sg.sliders]
  # bars = lift(sliderobservables...) do slvalues...
  #     [slvalues...]
  # end
  fig
end
