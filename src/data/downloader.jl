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
  layers = 1:ceil(Int, scan.slices / GRID_CELL_SIZE)
  @assert jz in layers "lz out of bounds"
  download_scan_slices(scan, grid_cell_range(jz, scan.slices))
end

"""
  download_grid_cell(scan::HerculaneumScan, jy, jx, jz)

Download a grid cell file from the vesuvius data server.
"""
download_grid_cell(scan::HerculaneumScan, jy, jx, jz) =
  download_file(grid_cell_server_path(scan, jy, jx, jz))

"""
  download_grid_cells(scan::HerculaneumScan, cells)

Download grid cell files from the vesuvius data server. (uses Threads.@threads)
"""
download_grid_cells(scan::HerculaneumScan, cells; quiet=false) = begin
  Threads.@threads for (jy, jx, jz) = cells
    quiet || println("Downloading grid cell ($jy, $jx, $jz)")
    download_grid_cell(scroll_1_54, jy, jx, jz)
  end
end

"""
  download_grid_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false)

Download a range of grid cells from the vesuvius data server.
"""
download_grid_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false) = begin
  for jy in jys, jx in jxs, jz in jzs
    filename = grid_cell_server_path(scan, jy, jx, jz)
    quiet || println("Downloading $filename...")
    download_file(filename)
  end
end

"""
  download_small_volume(scan::HerculaneumScan)

Download the scan's small (low resolution) volume from the vesuvius data server.
"""
download_small_volume(scan::HerculaneumScan) =
  download_file(small_volume_path(scan))


"""
  download_segment_obj(scan::HerculaneumScan, segment_id::String; hari=false)

Download a segment mesh from the vesuvius data server.
"""
download_segment_obj(scan::HerculaneumScan, segment_id::String; hari=false) = begin
  segment_dir = segment_path(scan, segment_id)
  mkpath(segment_dir)
  out = joinpath(segment_dir, "$segment_id.obj")
  if !isfile(out)
    download_file_to_out(segment_server_path(scan, segment_id; hari=hari) * "/$segment_id.obj", out)
  end
  out
end
