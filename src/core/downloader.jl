using Downloads, Base64, FileIO

const DATA_URL = "http://dl.ash2txt.org"
const DATA_AUTH = "registeredusers:only" # ENV["VESUVIUS_SERVER_AUTH"]


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

extract_server_dir_links(s) =
  [match(r"href=\"([^\"]*)/\"", l).captures[1] for l = split(s, "\n") if startswith(l, "<a ")]

list_server_segments(scan::HerculaneumScan; hari=false) = begin
  dir = segments_server_path(scan; hari=hari)
  buffer = IOBuffer()
  download_file_to_out(dir, buffer)
  dirstr = String(take!(buffer))
  filter(extract_server_dir_links(dirstr)) do segment_id
    !isnothing(match(r"^\d+$", segment_id))
  end
end

"""
  get_new_server_segments(scan::HerculaneumScan)

List all the new (not found locally) segments from the server.
"""
get_new_server_segments(scan::HerculaneumScan) = begin
  new_segments = []
  # for segment_id = list_server_segments(scan, hari=true)
  #   if !have_segment(scan, segment_id) push!(new_segments, segment_id) end
  # end
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
  # for segment_id = list_server_segments(scan, hari=true)
  #   download_segment_obj(scan, segment_id; hari=true, quiet=false)
  # end
  for segment_id = list_server_segments(scan, hari=false)
    download_segment_obj(scan, segment_id; hari=false, quiet=false)
  end
end


download_mesh_cells(scan, segment_id) = begin
  mesh = load_segment_mesh(scan, segment_id)
  cells = mesh_cells_missing(mesh)
  download_cells(scan, cells)
end
