import json
import tempfile
from stabia.core import *
from stabia.mesh_utils import *
import numpy as np
import open3d as o3d

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

def main(out_dir, *json_files):
  mkdir(out_dir)
  for json_file in json_files:
    jz_start, jz_end = map(int, json_file[-10:-5].split("_"))
    jx_split, jy_split = layer_ojs[jz_end]
    with open(json_file, 'r') as f:
      turns_chunk_names = json.load(f)
    with tempfile.TemporaryDirectory() as tmp_dir:
      for turn, (turn_name, turn_chunk_names) in enumerate(turns_chunk_names.items()):
        print(f"Poisson reconstructing turn {turn} ({turn_name})...")
        halves = [[], []]
        for chunk_name in turn_chunk_names:
          jy, jx, jz, _, _ = parse_chunk_name(chunk_name)
          halves[int(jx > jx_split)].append(chunk_name)
        for ihalf, half in enumerate(halves):
          point_cloud = o3d.geometry.PointCloud()
          if len(half) == 0:
            continue
          for chunk_name in half:
            point_cloud += o3d.io.read_point_cloud(str(chunk_points_path(chunk_name)))
          mesh_name = f"jzs_{jz_start:02d}_{jz_end:02d}_turn_{turn:02d}_half_{ihalf}"
          mesh_o3d, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(point_cloud, depth=8)
          densities = np.asarray(densities)
          # print(f"densities (min, max) == ({densities.min()}, {densities.max()})")
          # Tuned this value to remove the hanging sheets that appear when there
          # are no points nearby. The range is in the 2.0 to 8.0 ballpark.
          mesh_o3d.remove_vertices_by_mask(densities < 5.0)
          mesh_o3d.remove_non_manifold_edges()
          mesh_tmp_path = f"{tmp_dir}/{mesh_name}.ply"
          o3d.io.write_triangle_mesh(mesh_tmp_path, mesh_o3d)
          mesh = vtk_load_mesh_ply(mesh_tmp_path)
          mesh = clip_mesh(mesh, 0, 0, (jz_start-1)*500, 0, 0, 1)
          mesh = clip_mesh(mesh, 0, 0, jz_end*500, 0, 0, -1)
          mesh = clip_mesh(mesh, jx_split*500, 0, 0, -1 if ihalf == 0 else 1, 0, 0)
          vtk_save_mesh_stl(f"{out_dir}/{mesh_name}.stl", mesh)
