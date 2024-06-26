using Downloads, Base64, FileIO

const DATA_URL = "https://dl.ash2txt.org"
const DATA_AUTH = ENV["VESUVIUS_SERVER_AUTH"]


download_file_to_out(path::String, out) = begin
  url = "$DATA_URL/$path"
  auth = base64encode(DATA_AUTH)
  Downloads.download(url, out, headers=["Authorization" => "Basic $auth"])
end

"""
  download_file(path::String) :: String

Download a file from the vesuvius data server. It will be saved to `DATA_DIR/path`.
Returns the path of the downloaded file. Skips downloading if the file exists.
"""
download_file(path::String) = begin
  out = joinpath(DATA_DIR, path)
  if !isfile(out)
    download_file_to_out(path, out)
  end
  out
end


download_file_to_string(path) = begin
  buffer = IOBuffer()
  download_file_to_out(path, buffer)
  String(take!(buffer))
end

download_volpkg_scan_meta(volpkg_path::String, scan_id::String) = begin
  meta_path = "$volpkg_path/volumes/$scan_id/meta.json"
  scan_path = joinpath(DATA_DIR, volpkg_path, "volumes", scan_id)
  isdir(scan_path) || mkpath(scan_path)
  download_file(meta_path)
end

"""
  load_tiff_from_server(path::String)

Load a TIFF file from the vesuvius data server into memory without saving it to disk.
"""
load_tiff_from_server(path::String) = begin
  buffer = IOBuffer()
  download_file_to_out(path, buffer)
  bufstream = TiffImages.getstream(format"TIFF", buffer)
  TiffImages.load(read(bufstream, TiffFile))
end

"""
  download_scan_slice(scan::HerculaneumScan, iz::Int)

Download a slice file from the vesuvius data server.
"""
download_scan_slice(scan::HerculaneumScan, iz::Int) =
  download_file(scan_slice_filename(scan, iz))

"""
  download_scan_slices(scan::HerculaneumScan, slices::AbstractArray{Int}; quiet=false)

Download slice files from the vesuvius data server.
"""
download_scan_slices(scan::HerculaneumScan, slices::AbstractArray{Int}; quiet=false) = begin
  @assert isdir(DATA_DIR) "data directory not found"
  mkpath("$DATA_DIR/$(scan.volpkg_path)/volumes/$(scan.id)")
  nslices = length(slices)
  for (i, iz) in enumerate(slices)
    filename = scan_slice_filename(scan, iz)
    quiet || println("Downloading $filename ($i/$nslices)...")
    download_file(scan_slice_server_path(scan, iz))
  end
end

"""
  download_grid_layer_slices(scan::HerculaneumScan, jz::Int)

Download the slices of a layer of the cell grid from the vesuvius data server.
"""
download_grid_layer_slices(scan::HerculaneumScan, jz::Int) = begin
  layers = 1:ceil(Int, scan.slices / CELL_SIZE)
  @assert jz in layers "lz out of bounds"
  download_scan_slices(scan, cell_range(jz, scan.slices))
end

"""
  download_cell(scan::HerculaneumScan, jy, jx, jz)

Download a grid cell file from the vesuvius data server.
"""
download_cell(scan::HerculaneumScan, jy, jx, jz) =
  download_file(cell_server_path(scan, jy, jx, jz))

"""
  download_cells(scan::HerculaneumScan, cells)

Download grid cell files from the vesuvius data server. (uses Threads.@threads)
"""
download_cells(scan::HerculaneumScan, cells; quiet=false) = begin
  Threads.@threads for (jy, jx, jz) = cells
    quiet || println("Downloading grid cell ($jy, $jx, $jz)")
    download_cell(scan, jy, jx, jz)
  end
end

"""
  download_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false)

Download a range of grid cells from the vesuvius data server.
"""
download_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false) = begin
  for jy in jys, jx in jxs, jz in jzs
    filename = cell_server_path(scan, jy, jx, jz)
    quiet || println("Downloading $filename...")
    download_file(filename)
  end
end

"""
  download_cells_layer(scan::HerculaneumScan, jz)

Download a layer of grid cells from the vesuvius data server. Masked to cells with data.
"""
download_cells_layer(scan::HerculaneumScan, layer_jz::Int) = begin
  # Either this is kind of buggy or pherc_1667's mask has some holes.
  mask = scan_mask(scan)
  Threads.@threads for thread_jy in 1:ceil(Int, scan.height / CELL_SIZE)
    for r = 1:size(mask, 1)
      jy, jx, jz = mask[r, :]
      if jz == layer_jz && jy == thread_jy
        download_cell(scan, jy, jx, jz)
        println("downloaded $jy $jx $jz")
      end
    end
  end
end

"""
  download_small_volume(scan::HerculaneumScan)

Download the scan's small (low resolution) volume from the vesuvius data server.
"""
download_small_volume(scan::HerculaneumScan) =
  download_file(small_volume_server_path(scan))


"""
  download_segment_obj(scan::HerculaneumScan, segment_id::String; hari=false)

Download a segment mesh from the vesuvius data server.
"""
download_segment_obj(scan::HerculaneumScan, segment_id::AbstractString; hari=false, quiet=true) = begin
  segment_dir = segment_path(scan, segment_id)
  mkpath(segment_dir)
  out = joinpath(segment_dir, "$segment_id.obj")
  if !isfile(out)
    if !quiet
      println("Downloading $segment_id...")
    end
    download_file_to_out(segment_server_path(scan, segment_id; hari=hari) * "/$segment_id.obj", out)
  end
  out
end

extract_server_dir_links(s) = begin
  links = []
  for l = split(s, "\n")
    if startswith(l, "<tr><td class=\"link\"><a ")
      m = match(r"href=\"([^\"]*)/\"", l)
      if !isnothing(m)
        push!(links, m.captures[1])
      end
    end
  end
  links
end

get_server_dir_links(path) =
  extract_server_dir_links(download_file_to_string(path))

list_scans(path) = begin
  folders = get_server_dir_links(path)
  scans = Dict{String, Vector{String}}()
  for folder in folders
    volpkgs = get_server_dir_links("$path/$folder")
    for volpkg in volpkgs
      scans["$folder/$volpkg"] = get_server_dir_links("$path/$folder/$volpkg/volumes")
    end
  end
  scans
end

list_scroll_scans() =
  list_scans("full-scrolls")

list_fragment_scans() =
  list_scans("fragments")

download_scan_metas(path) = begin
  scans = []
  for (volpkg, scan_ids) in list_scans(path)
    for scan_id in scan_ids
      volpkg_path = "$path/$volpkg"
      download_volpkg_scan_meta(volpkg_path, scan_id)
      push!(scans, scan_from_volpkg(volpkg_path, scan_id))
    end
  end
  scans
end

download_scroll_scan_metas() =
  download_scan_metas("full-scrolls")

download_fragment_scan_metas() =
  download_scan_metas("fragments")

list_server_segments(scan::HerculaneumScan; hari=false) = begin
  dir = segments_server_path(scan; hari=hari)
  links = get_server_dir_links(dir)
  filter(links) do segment_id
    !isnothing(match(r"^\d+$", segment_id))
  end
end

"""
  get_new_server_segments(scan::HerculaneumScan)

List all the new (not found locally) segments from the server.
"""
get_new_server_segments(scan::HerculaneumScan) = begin
  new_segments = []
  for segment_id = list_server_segments(scan, hari=false)
    if !have_segment(scan, segment_id) push!(new_segments, segment_id) end
  end
  new_segments
end

"""
  download_segment_objs(scan::HerculaneumScan)

Download all segments obj files.
"""
download_segment_objs(scan::HerculaneumScan) = begin
  for segment_id = list_server_segments(scan, hari=false)
    download_segment_obj(scan, segment_id; hari=false, quiet=false)
  end
end


download_mesh_cells(scan, segment_id) = begin
  mesh = load_segment_mesh(scan, segment_id)
  cells = mesh_cells_missing(mesh)
  download_cells(scan, cells)
end



# Coverage #####################################################################

layer_coverage(scan::HerculaneumScan, layer_jz::Int) = begin
  mask = scan_mask(scan)
  have = 0
  total = 0
  for r = 1:size(mask, 1)
    jy, jx, jz = mask[r, :]
    if jz == layer_jz
      total += 1
      if have_cell(scan, jy, jx, jz)
        have += 1
      end
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end

grid_coverage(scan::HerculaneumScan) = begin
  mask = scan_mask(scan)
  have = 0
  total = size(mask, 1)
  for r = 1:total
    jy, jx, jz = mask[r, :]
    if have_cell(scan, jy, jx, jz)
      have += 1
    end
  end
  frac = have/total
  println("$have / $total  ($frac)")
  frac, have, total, total - have
end



estimate_layer(scan::HerculaneumScan, layer_jz::Int) = begin
  println("\nLayer $layer_jz:")
  _, have, total, lack = layer_coverage(scan, layer_jz)
  space_req_gb = round(Int, lack * 244220 / 1024 / 1024)
  time_est = (space_req_gb / 0.030) / 60
  println("space required: $space_req_gb G  ($time_est min @ 30M/s)")
  space_req_gb
end

estimate_required_space_by_layer_gb(scan::HerculaneumScan) =
  [estimate_layer(scan, jz) for jz in 1:ceil(Int, div(scan.slices, CELL_SIZE))]
