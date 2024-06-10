# When new scans are released, running `download_scroll_scan_metas()` will find
# all volpkgs and scans from the server full-scrolls directory, download all
# their meta.json files if needed and return a list of HerculaneumScans which
# can be copy-pasted to here.

# https://scrollprize.org/data_scrolls

const scroll_1a_791_54 = HerculaneumScan("full-scrolls/Scroll1/PHercParis4.volpkg", "20230205180739", 7.91f0, 54.0f0,  8096,  7888, 14376)
const scroll_1b_791_54 = HerculaneumScan("full-scrolls/Scroll1/PHercParis4.volpkg", "20230206171837", 7.91f0, 54.0f0,  8316,  7812, 10532)
const scroll_2a_791_54 = HerculaneumScan("full-scrolls/Scroll2/PHercParis3.volpkg", "20230210143520", 7.91f0, 54.0f0, 11984, 10112, 14428)
const scroll_2a_791_88 = HerculaneumScan("full-scrolls/Scroll2/PHercParis3.volpkg", "20230212125146", 7.91f0, 88.0f0, 11136,  8480,  1610)
const scroll_2b_791_54 = HerculaneumScan("full-scrolls/Scroll2/PHercParis3.volpkg", "20230206082907", 7.91f0, 54.0f0, 11296,  8448,  6586)
const scroll_3_324_53  = HerculaneumScan("full-scrolls/Scroll3/PHerc332.volpkg",    "20231027191953", 3.24f0, 53.0f0,  9414,  9414, 22941)
const scroll_3_791_53  = HerculaneumScan("full-scrolls/Scroll3/PHerc332.volpkg",    "20231117143551", 7.91f0, 53.0f0,  3400,  3550,  9778)
const scroll_3_324_70  = HerculaneumScan("full-scrolls/Scroll3/PHerc332.volpkg",    "20231201141544", 3.24f0, 70.0f0,  9414,  9414, 22932)
const scroll_4_324_88  = HerculaneumScan("full-scrolls/Scroll4/PHerc1667.volpkg",   "20231107190228", 3.24f0, 88.0f0,  8120,  7960, 26391)
const scroll_4_791_53  = HerculaneumScan("full-scrolls/Scroll4/PHerc1667.volpkg",   "20231117161658", 7.91f0, 53.0f0,  3440,  3340, 11174)

scroll_scans = [
  scroll_1a_791_54,
  scroll_1b_791_54,
  scroll_2a_791_54,
  scroll_2a_791_88,
  scroll_2b_791_54,
  scroll_3_324_53,
  scroll_3_791_53,
  scroll_3_324_70,
  scroll_4_324_88,
  scroll_4_791_53,
]

# Aliases. The "canonical" or "main" scan for a scroll.
const scroll_1a = scroll_1a_791_54
const scroll_1b = scroll_1b_791_54
const scroll_2a = scroll_2a_791_54
const scroll_2b = scroll_2b_791_54
const scroll_3  = scroll_3_324_53
const scroll_4  = scroll_4_324_88

include("scroll_1a.jl")
include("scroll_1a_segments.jl")
# include("scroll_1b.jl")
include("scroll_2a.jl")
# include("scroll_2b.jl")
include("scroll_3.jl")
include("scroll_4.jl")
