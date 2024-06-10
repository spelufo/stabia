# This wraps the ACVD program from https://github.com/valette/ACVD .
# You must build it and put it on your PATH for this to work.

remesh_acvd(in_path::String, out_dir::String, out_filename::String, n_vert_ratio::Float32, subdivs::Int; dryrun=false) = begin
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
  # The -s flag determines, together with n_verts, how many subdivisions it will
  # make before processing. Every subdivision increases memory usage by a factor
  # of 4 and these are big meshes. Adjust accordingly. If it starts to swap it
  # will take forever.

  n_verts_in = ply_n_verts(in_path)
  n_verts_out = round(Int, n_verts_in*n_vert_ratio)
  # Each subdivision multiplies the number of vertices roughly by a factor of 4.
  # So: n_verts_in * 4^(subdivs-1)  <=  s * n_verts_out  <  n_verts_in * 4^subdivs.
  # To find s given subdivs, we can choose it such that:
  # n_verts_in * 4^(subdivs-1/2) = n_verts_in * 4^subdivs / 2 = s * n_verts_out.
  # s = floor(Int, n_verts_in * 4^(subdivs-1) / n_verts_out)
  s = floor(Int, n_verts_in * 4^subdivs / (2*n_verts_out))
  path = relpath(in_path, out_dir)
  g = 1 # What's the upper bound on this "gradation" param? What should we use?
  cmd = `ACVD $path $n_verts_out $g -s $s -m 1 -of $out_filename`
  println("Running $cmd ...")
  if dryrun
    run(`echo`) # Just so return type is type stable.
  else
    run(Cmd(cmd, dir=out_dir))
  end
end

remesh_column_meshes(in_dir::String, out_dir::String; dryrun=false) = begin
  @assert isdir(in_dir) "in_dir is not a directory"
  isdir(out_dir) || !dryrun && mkdir(out_dir)
  for filename = readdir(in_dir)
    endswith(filename, ".ply") || continue
    in_path = joinpath(in_dir, filename)
    out_filename = replace(filename, ".ply" => "_acvd.ply")
    # Poisson has lots of vertices we can do without without loosing much quality.
    # We target half the number of vertices. The number of subdivisions needs to
    # be at least 1 to get nice looing results. Zero works but isn't as good.
    # Memory usage quadruples with each subdiv though, so we also want it as low
    # as possible. So we use 1. It does take much longer than 0 though...
    n_vert_ratio = 0.5f0
    subdivs = 1
    remesh_acvd(in_path, out_dir, out_filename, n_vert_ratio, subdivs, dryrun=dryrun)
  end
end
