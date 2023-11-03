@inline cell_px_to_perp_px(cell::Cell, perp::Perp, p::Vec3f) =
  Vec2f(dot(p - world_to_cell_px(cell, perp.p), perp_u(perp)), dot(p - perp.p, Ez))

@inline perp_px_to_cell_px(cell::Cell, perp::Perp, p::Vec2f) =
  world_to_cell_px(cell, perp.p) + p[1]*perp_u(perp) + p[2]*Ez

@inline world_to_perp_px(cell::Cell, perp::Perp, p::Vec3f) =
  cell_px_to_perp_px(cell, perp, world_to_cell_px(cell, p))

@inline perp_px_to_world(cell::Cell, perp::Perp, p::Vec2f) =
  cell_px_to_world(cell, perp_px_to_cell_px(cell, perp, p))

# TODO: Hardcoding this means the window for the perp slices depends on where
# the perps[1].p is, and that right now is just where the user clicked. We need
# some smarts to determine a tight range that includes all the voxels in the cell.
# An easy version is to sweep the perps.t calling perp_box_bounds to measure it.
const PERP_SLICES_WL = 249
const PERP_SLICES_WR = 250

@inline perp_px_to_perp_slice(perp::Perp, p::Vec2f) = 
  (round(Int, 500 - perp.p[2] - p[2]) + 1, round(Int, p[1] + PERP_SLICES_WL) + 1)

@inline perp_slice_to_perp_px(perp::Perp, iy::Int, ix::Int) =
  Vec2f(ix - PERP_SLICES_WL - 1, 501 - perp.p[2] - iy)

@inline perp_slice_to_cell_px(cell::Cell, perp::Perp, iy::Int, ix::Int) =
  perp_px_to_cell_px(cell, perp, perp_slice_to_perp_px(perp, iy, ix))

@inline cell_px_to_perp_slice(cell::Cell, perp::Perp, p::Vec3f) =
  perp_px_to_perp_slice(cell, perp, cell_px_to_perp_px(cell, perp, p))


build_perp_slices!(cell::Cell, perps::Perps) = begin
  width = PERP_SLICES_WR + PERP_SLICES_WL + 1
  slice_range = 0f0:perps.slices_dt:perps_walk_length(perps)
  perps.slices = zeros(Gray{Float32}, 500, width, length(slice_range))
  for (iz, t) = enumerate(slice_range)
    perp = perps_walk_eval_perp(perps.walk, t)
    for ix = 1:size(perps.slices, 2), iy = 1:size(perps.slices, 1)
      p = perp_slice_to_cell_px(cell, perp, iy, ix)
      perps.slices[iy, ix, iz] = cell.W(p...)
    end
  end
  nothing
end

# TODO: Why all the allocations? This shouldn't need to allocate at all, really.
# @time build_perp_slices!(the_editor.cell, the_editor.perps);
#  11.283398 seconds (277.99 M allocations: 5.752 GiB, 3.95% gc time, 0.56% compilation time)


build_perp_flow!(cell::Cell, perps::Perps) = begin
  perps.flow = zeros(SVector{2, Float64}, size(perps.slices))
  for i = 1:size(perps.slices, 3)-1
    S0 = @view perps.slices[:,:,i]
    S1 = @view perps.slices[:,:,i+1]
    # TODO: Tune Farneback params.
    perps.flow[:,:,i] .= optical_flow(
      S0, S1,
      Farneback( 3, estimation_window = 7, σ_estimation_window = 4.0,
                    expansion_window  = 6, σ_expansion_window  = 5.0 ))
  end
  nothing
end

# TODO: Also a lot of allocation. Any way to improve things?
# @time build_perp_flow!(the_editor.cell, the_editor.perps);
#  39.700848 seconds (923.01 k allocations: 18.666 GiB, 0.52% gc time, 8.98% compilation time)


extend_trace_with_flow(cell::Cell, perps::Perps, trace::Vector{Vec3f}, t::Float32) = begin
  perp = perps_walk_eval_perp(perps.walk, t)
  perp_next = perps_walk_eval_perp(perps.walk, t + perps.slices_dt)
  iz = floor(Int, t/perps.slices_dt) + 1
  trace_next = zeros(Vec3f, length(trace))
  for (i, p) = enumerate(trace)
    p_perp_px = world_to_perp_px(cell, perp, p)
    iy, ix = perp_px_to_perp_slice(perp, p_perp_px)
    p_perp_px += perps.flow[iy, ix, iz]
    p_next = perp_px_to_world(cell, perp_next, p_perp_px)
    trace_next[i] = p_next  # TODO: return a new trace instead?
  end
  trace_next
end
