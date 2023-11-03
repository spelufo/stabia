include("../src/core/core.jl")


layer_coverage(layer_jz::Int) = begin
  have = 0
  total = 0
  for r = 1:size(scroll_1_54_mask, 1)
    jy, jx, jz = scroll_1_54_mask[r, :]
    if jz == layer_jz
      total += 1
      if have_cell(scroll_1_54, jy, jx, jz)
        have += 1
      end
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end

grid_coverage() = begin
  have = 0
  total = size(scroll_1_54_mask, 1)
  for r = 1:total
    jy, jx, jz = scroll_1_54_mask[r, :]
    if have_cell(scroll_1_54, jy, jx, jz)
      have += 1
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end


estimate_layer(layer_jz::Int) = begin
  println("\nLayer $layer_jz:")
  _, have, total, lack = layer_coverage(layer_jz)
  space_req_gb = round(Int, lack * 244216 / 1024 / 1024)
  time_est = (space_req_gb / 0.030) / 60
  println("space required: $space_req_gb G  ($time_est min @ 30M/s)")
  space_req_gb
end

estimate_required_space_by_layer_gb() =
  [estimate_layer(jz) for jz in 1:29]


download_layer(layer_jz::Int) = begin
  Threads.@threads for thread_jy in 1:ceil(Int, scroll_1_54.height / 500)
    for r = 1:size(scroll_1_54_mask, 1)
      jy, jx, jz = scroll_1_54_mask[r, :]
      if jz == layer_jz && jy == thread_jy
        download_cell(scroll_1_54, jy, jx, jz)
        println("downloaded $jy $jx $jz")
      end
    end
  end
end

