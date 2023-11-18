# The goal is to filter a set of meshes (sheet holes) by proximity to another
# (segment). The proximity is approximate/hacky: we compute a coarse mask within
# each cell of cubes of a certain size that contain vertices of the segment, and
# then filter sheet holes

# NOTE: Stalled on this because I'd need to export each patch to a separate file
# since exporting a whole layer at once produces a single Mesh. Instead, I'm
# porting this to run within blender.

patches_close_to_segment(scan::HerculaneumScan, segment::Mesh) = begin
  mask_index(j::Ints3, p) = begin
    nsubdivs = 20
    p0 = ((j[2], j[1], j[3]) .- 1).*CELL_SIZE
    div.(p - p0, CELL_SIZE / nsubdivs) .+ 1
  end

  # Compute the segment's masks.
  segment_masks = Dict{Ints3, Array{Bool, 3}}()
  for p in segment.points
    jp = div.(p, CELL_SIZE) .+ 1
    if !(jp in segment_masks)
      segment_masks[jp] = zeros(Bool, ndivs, ndivs, ndivs)
    end
    mask = segment_masks[jp]
    mask[mask_index(jp, p)] = true
  end

  # Find patches with points int the segment masks.
  patches = []
  for jz = 1:grid_size(scan, 3)
    layer_segment_masks = [(j, m) for (j, m) in segment_masks if j[3] == jz]
    if length(js) == 0
      continue
    end
    layer_patches = load_layer_patches(scan, jz)
    for (j, mask) = layer_segment_masks
      for patch = layer_patches
        for p in patch.points
          if mask[mask_index(j, p)]
            push!(patches, patch)
            break
          end
        end
      end
    end
    Base.GC.gc()
  end
  patches
end

