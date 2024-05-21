# When new scans are released, running `download_scroll_scan_metas()` will find
# all volpkgs and scans from the server full-scrolls directory, download all
# their meta.json files if needed and return a list of HerculaneumScans which
# can be copy-pasted to here.

# https://scrollprize.org/data_scrolls

const scroll_1_54       = HerculaneumScan("full-scrolls/Scroll1.volpkg",  "20230205180739", 7.91f0, 54.0f0,  8096,  7888, 14376)
const pherc_paris_4_54  = scroll_1_54

const scroll_2_54       = HerculaneumScan("full-scrolls/Scroll2.volpkg",  "20230210143520", 7.91f0, 54.0f0, 11984, 10112, 14428)
const pherc_paris_3_54  = scroll_2_54
const scroll_2_88       = HerculaneumScan("full-scrolls/Scroll2.volpkg",  "20230212125146", 7.91f0, 88.0f0, 11136,  8480,  1610)
const pherc_paris_3_88  = scroll_2_88

const scroll_3_53       = HerculaneumScan("full-scrolls/PHerc0332.volpkg", "20231027191953", 3.24f0, 53.0f0,  9414,  9414, 22941)
const pherc_0332_53     = scroll_3_53
const scroll_3_53_791   = HerculaneumScan("full-scrolls/PHerc0332.volpkg", "20231117143551", 7.91f0, 53.0f0,  3400,  3550,  9778)
const pherc_0332_53_791 = scroll_3_53_791
const scroll_3_70       = HerculaneumScan("full-scrolls/PHerc0332.volpkg", "20231201141544", 3.24f0, 70.0f0,  9414,  9414, 22932)
const pherc_0332_70     = scroll_3_70

const scroll_4_88       = HerculaneumScan("full-scrolls/PHerc1667.volpkg", "20231107190228", 3.24f0, 88.0f0,  8120,  7960, 26391)
const pherc_1667_88     = scroll_4_88
const scroll_4_53       = HerculaneumScan("full-scrolls/PHerc1667.volpkg", "20231117161658", 7.91f0, 53.0f0,  3440,  3340, 11174)
const pherc_1667_53     = scroll_4_53

scroll_scans = [
  scroll_1_54,
  scroll_2_54,
  scroll_2_88,
  scroll_3_53,
  scroll_3_53_791,
  scroll_3_70,
  scroll_4_88,
  scroll_4_53,
]

include("scroll_1_54.jl")
include("scroll_1_54_segments.jl")
include("scroll_2_54.jl")
include("scroll_2_88.jl")
include("pherc_0332_53.jl")
include("pherc_0332_53_791.jl")
include("pherc_0332_70.jl")
include("pherc_1667_88.jl")
include("pherc_1667_53.jl")

