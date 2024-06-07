remesh_acvd(in_path::String, out_dir::String, out_filename::String, nverts::Int) = begin
  # Usage : ACVD file nvertices gradation [options]
  # nvertices is the desired number of vertices
  # gradation defines the influence of local curvature (0=uniform meshing)
  # -b 0/1 : sets mesh boundary fixing off/on (default : 0)
  # -s threshold : defines the subsampling threshold i.e. the input mesh will be subdivided until inputVertices > outputVertices * ratio
  # -o directory : sets the output directory 
  # -of file : sets the output file name 
  #  of vertices is above nvertices*threshold (default=10)
  # -d 0/1/2 : enables display (default : 0)
  # -l ratio : split the edges longer than ( averageLength * ratio )
  # -q 0/1/2 : set the number of eigenvalues for quadrics post-processing (default : 3)
  # -cd file : set custom imagedata file containing density information
  # -cmin value : set minimum custom indicator value
  # -cmax value : set maximum custom indicator value
  # -cf value : set custom indicator multiplication factor
  # -m 0/1 : enforce a manifold output off/on (default : 0)

  # NOTES:
  # The -m flag usage said on/off which is wront. 1 means on. We want it on.
  # The -b boundary fixing option doesn't work, it crashes.
  # The -s flag determines, together with nverts, how many subdivisions it will
  # make before processing. Every subdivision increases memory usage by a factor
  # of 4 and these are big meshes. Adjust accordingly. If it starts to swap it
  # will take forever.

  gradation = 1 # What's a good value for this? Read the paper to know what it does?
  path = relpath(in_path, out_dir)
  run(Cmd(`ACVD $path $nverts $gradation -s 2 -m 1 -of $out_filename`, dir=out_dir))
end

remesh_column_meshes(in_dir::String, out_dir::String) = begin
  @assert isdir(in_dir) "in_dir is not a directory"
  isdir(out_dir) || mkdir(out_dir)
  for filename = readdir(in_dir)
    endswith(filename, ".ply") || continue
    in_path = joinpath(in_dir, filename)
    out_filename = replace(filename, ".ply" => "_acvd.ply")
    remesh_acvd(in_path, out_dir, out_filename, 400000)
  end
end
