# When new scans are released, running `download_fragment_scan_metas()` will find
# all volpkgs and scans from the server fragments directory, download all
# their meta.json files if needed and return a list of HerculaneumScans which
# can be copy-pasted to here.

fragment_scans = [
  HerculaneumScan("fragments/Frag1.volpkg",             "20230205142449", 3.24f0, 54.0f0,  7198, 1399,  7219),
  HerculaneumScan("fragments/Frag1.volpkg",             "20230213100222", 3.24f0, 88.0f0,  7332, 1608,  7229),
  HerculaneumScan("fragments/Frag2.volpkg",             "20230216174557", 3.24f0, 54.0f0,  9984, 2288, 14111),
  HerculaneumScan("fragments/Frag2.volpkg",             "20230226143835", 3.24f0, 88.0f0, 10035, 2112, 14144),
  HerculaneumScan("fragments/Frag3.volpkg",             "20230215142309", 3.24f0, 54.0f0,  6312, 1440,  6656),
  HerculaneumScan("fragments/Frag3.volpkg",             "20230212182547", 3.24f0, 88.0f0,  6108, 1644,  6650),
  HerculaneumScan("fragments/Frag4.volpkg",             "20230215185642", 3.24f0, 54.0f0,  5808, 1968,  9231),
  HerculaneumScan("fragments/Frag4.volpkg",             "20230222173037", 3.24f0, 88.0f0,  5957, 1969,  9209),
  HerculaneumScan("fragments/PHerc0051Cr04Fr08.volpkg", "20231121152933", 3.24f0, 53.0f0,  6300, 2260,  8855),
  HerculaneumScan("fragments/PHerc0051Cr04Fr08.volpkg", "20231130112027", 7.91f0, 53.0f0,  2724, 1068,  3683),
  HerculaneumScan("fragments/PHerc0051Cr04Fr08.volpkg", "20231201112849", 3.24f0, 88.0f0,  6300, 2260,  8855),
  HerculaneumScan("fragments/PHerc0051Cr04Fr08.volpkg", "20231201120546", 3.24f0, 70.0f0,  6300, 2260,  8855),
  HerculaneumScan("fragments/PHerc1667Cr01Fr03.volpkg", "20231121133215", 3.24f0, 70.0f0,  4420, 1400,  7010),
  HerculaneumScan("fragments/PHerc1667Cr01Fr03.volpkg", "20231130111236", 7.91f0, 70.0f0,  2046,  668,  3131),
]

