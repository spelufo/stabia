include("../src/core/core.jl")

# gp_segments = [
#   "20230702185753", # 001
#   "20231005123336", # 005, 006
#   "20231022170900", # 002, 003
#   "20231031143852", # 002
#   "20231024093300", # 002
#   "20231106155351", # 003
#   "20231012184421", # 004
#   "20231012173610", # 004
# ]

gp_segments = [
  "20230929220926",
  "20231005123336",
  "20231007101619",
  "20231210121321",
  "20231012184424",
  "20231022170901",
  "20231221180251",
  "20231106155351",
  "20231031143852",
  "20230702185753",
  "20231016151002",
]

gp_cells = Set()
gp_cells_by_segment = Dict{String,Any}()
for segid in gp_segments
  println("Gettings cells for $segid...")
  segcells = segment_cells(scroll_1_54, segid)
  gp_cells_by_segment[segid] = segcells
  union!(gp_cells, segcells)
end


# julia> length(gp_cells)
# 754
