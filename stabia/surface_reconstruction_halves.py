import json
import tempfile
from stabia.core import *
from stabia.mesh_utils import *
import numpy as np
import open3d as o3d
import networkx

layer_ojs = {}  # layer_ojs[jz] == (ojx, ojy)
for jz in [1, 2, 3, 4]:
  layer_ojs[jz] = (8, 5)
for jz in [5, 6, 7, 8, 9]:
  layer_ojs[jz] = (8, 4)
for jz in [10, 11]:
  layer_ojs[jz] = (8, 5)
for jz in [12]:
  layer_ojs[jz] = (8, 6)
for jz in [13, 14]:
  layer_ojs[jz] = (8, 7)
for jz in [15, 16, 17, 18, 19, 20, 21]:
  layer_ojs[jz] = (7, 7)
for jz in [22, 23, 24, 25]:
  layer_ojs[jz] = (6, 8)
for jz in [26, 27, 28, 29]:
  layer_ojs[jz] = (6, 9)

def parse_chunk_name(name):
  # e.g. 'cell_yxz_005_007_001_sadj_chunk_recon_01_20230702185753002',
  parts = name.split("_")
  jy, jx, jz = parts[2:5]
  i, chunk_id = parts[-2:]
  return int(jy), int(jx), int(jz), int(i) , chunk_id

def chunk_path(name):
  return segmentation_dir() / name[:20] / "chunks_recon" / f"{name}.stl"

def chunk_points_path(name):
  pc_name = name.replace("chunk_recon", "fronts")
  return segmentation_dir() / name[:20] / "sadjs" / f"{pc_name}.ply"

def mesh_cleanup(mesh_o3d):
  mesh_o3d.remove_non_manifold_edges()
  mesh_o3d.merge_close_vertices(0.001)
  mesh_o3d.remove_duplicated_vertices()
  mesh_o3d.remove_duplicated_triangles()
  mesh_o3d.remove_unreferenced_vertices()
  mesh_o3d.remove_degenerate_triangles()
  # This seems to keep the majority normal direction, but without knowing
  # how it works there's the risk that it flips all the faces.
  mesh_o3d.orient_triangles()

  cis, cns, cas = mesh_o3d.cluster_connected_triangles()
  # print("component areas pre-cleanup:", cas)
  max_area = max(cas)
  # Any small value will remove the little bubble artifact components we are
  # after. For the assembly sheets, I expect a single big component. This can be
  # false when a umbilicus cell has a bit of sheet from the opposite half of the
  # turn. A higher value like max_area/2 will likely get rid of these too, which
  # is easier, but we will want to grab that component later to fill the hole
  # on the other half turn.
  max_allowed_area = max_area/3
  remove_components = []
  for i, area in enumerate(cas):
    if area < max_allowed_area:
      remove_components.append(i)
  mesh_o3d.remove_triangles_by_mask([ci in remove_components for ci in cis])
  mesh_o3d.remove_unreferenced_vertices()

  # Fill holes: this may help but may also cost us a fair bit of time too.
  # We need to convert to the new o3d format, then it converts to vtk internally
  # (TODO: call vtk directly), which copies the data again...
  # mesh_o3d = o3d.t.geometry.TriangleMesh.from_legacy(m).fill_holes(hole_size=50.0).to_legacy()

  return mesh_o3d

def mesh_report(mesh_o3d, name):
  _, _, cas = mesh_o3d.cluster_connected_triangles()
  n_components = len(cas)
  X = mesh_o3d.euler_poincare_characteristic()
  nonmanifold_edges = mesh_o3d.get_non_manifold_edges(allow_boundary_edges=True)
  boundary_edges = mesh_o3d.get_non_manifold_edges(allow_boundary_edges=False)
  n_boundary_edges = len(boundary_edges) - len(nonmanifold_edges)
  g = networkx.Graph()
  g.add_edges_from(boundary_edges)
  n_boundary_loops = networkx.number_connected_components(g)
  genus =  1 - (X + n_boundary_loops*n_components)/2
  print(name,
    "\tn_components:", n_components,
    "\tareas:", list(map(round, cas)),
    "\tgenus:", genus,
    "\tn_boundary_edges:", n_boundary_edges,
    "\tn_boundary_loops:", n_boundary_loops,
    "\tX:", X)

def poisson_depth_from_width_and_scale(pcd, width, scale_factor):
  bbox = pcd.get_axis_aligned_bounding_box()
  p_min = bbox.get_min_bound()
  p_max = bbox.get_max_bound()
  resolution = max((p_max - p_min) / width)
  resolution *= scale_factor
  depth = 0
  while ((1 << depth) < resolution):
      depth += 1
  return depth

def create_from_point_cloud_poisson(pcd, depth=8, width=0, scale=1.1, **kwargs):
  # Work around open3d's poisson width bug:
  # https://github.com/isl-org/Open3D/issues/5842#issuecomment-2133275951
  if width > 0:
    depth = poisson_depth_from_width_and_scale(pcd, width, scale)
  return o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
    pcd, width=width, depth=depth, scale=scale, **kwargs
  )

def main(out_dir, *json_files):
  # o3d.utility.set_verbosity_level(o3d.utility.VerbosityLevel.Debug)
  mkdir(out_dir)
  for json_file in json_files:
    jz_start, jz_end = map(int, json_file[-10:-5].split("_"))
    jx_split, jy_split = layer_ojs[jz_end]
    with open(json_file, 'r') as f:
      turns_chunk_names = json.load(f)
    with tempfile.TemporaryDirectory() as tmp_dir:
      for turn, (turn_name, turn_chunk_names) in enumerate(turns_chunk_names.items()):
        turn_abs = turn+1 if jz_start >= 10 else turn + 5
        turn_abs_name = f"jzs_{jz_start:02d}_{jz_end:02d}_turn_{turn_abs:02d}"
        print(f"Reconstructing {turn_abs_name} (from {turn_name})...")
        halves = [[], []]
        for chunk_name in turn_chunk_names:
          jy, jx, jz, _, _ = parse_chunk_name(chunk_name)
          halves[int(jx <= jx_split)].append(chunk_name)
        for ihalf, half in enumerate(halves):
          point_cloud = o3d.geometry.PointCloud()
          if len(half) == 0:
            continue
          for chunk_name in half:
            point_cloud += o3d.io.read_point_cloud(str(chunk_points_path(chunk_name)))
          mesh_name = f"{turn_abs_name}_h{ihalf+1}"
          # The poisson_width parameter determines the granularity / smoothness
          # of the result. Twice the scan resolution preserves the surface geometry
          # well while smoothing out the highest frequency kinks.
          scan_res = 7.91; poisson_width = 2*scan_res
          mesh_o3d, densities = create_from_point_cloud_poisson(point_cloud, width=poisson_width)
          o3d.io.write_point_cloud(f"{out_dir}/{mesh_name}.ply", point_cloud)
          densities = np.asarray(densities)
          # print(f"densities (min, max) == ({densities.min()}, {densities.max()})")
          # Tuned this value to remove the hanging sheets that appear when there
          # are no points nearby. The range is in the 2.0 to 8.0 ballpark.
          # TODO: Poisson shouldn't produce inner holes in the mesh, but deleting
          # vertices by density like this can. Removing only the ones that won't
          # create holes in the mesh when removed would be better.
          mesh_o3d.remove_vertices_by_mask(densities < 5.0)
          mesh_o3d = mesh_cleanup(mesh_o3d)
          mesh_report(mesh_o3d, mesh_name)
          mesh_tmp_path = f"{tmp_dir}/{mesh_name}.ply"
          o3d.io.write_triangle_mesh(mesh_tmp_path, mesh_o3d)
          mesh = vtk_load_mesh_ply(mesh_tmp_path)
          mesh = clip_mesh(mesh, 0, 0, (jz_start-1)*500, 0, 0, 1)
          mesh = clip_mesh(mesh, 0, 0, jz_end*500, 0, 0, -1)
          mesh = clip_mesh(mesh, jx_split*500, 0, 0, 1 if ihalf == 0 else -1, 0, 0)
          vtk_save_mesh_stl(f"{out_dir}/{mesh_name}.stl", mesh)
