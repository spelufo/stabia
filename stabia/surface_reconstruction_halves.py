import tempfile
from stabia.core import *
from stabia.mesh_utils import *
import open3d as o3d


layers_by_oj = {
  ( 1,  4): (8, 5),
  ( 5,  7): (8, 4),
  ( 8,  9): (8, 4),
  (10, 11): (8, 5),
  (12, 12): (8, 6),
  (13, 14): (8, 7),
  (15, 18): (7, 7),
  (19, 21): (7, 7),
  (22, 25): (6, 8),
  (26, 29): (6, 9),
}

jz_start = 21
jz_end = 25
jx_split = 6

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

def main():
  out_dir = DATA_DIR / "recon" / "halves_22_25"
  mkdir(out_dir)
  with tempfile.TemporaryDirectory() as tmp_dir:
    for turn, turn_chunk_names in enumerate(turns_chunk_names):
      halves = [[], []]
      for chunk_name in turn_chunk_names:
        jy, jx, jz, _, _ = parse_chunk_name(chunk_name)
        # halves[int(jy > jy_split)].append(chunk_name)
        halves[int(jx > jx_split)].append(chunk_name)
      for ihalf, half in enumerate(halves):
        point_cloud = o3d.geometry.PointCloud()
        if len(half) == 0:
          continue
        for chunk_name in half:
          point_cloud += o3d.io.read_point_cloud(str(chunk_points_path(chunk_name)))
        print("Poisson reconstructing turn", turn, "half", ihalf)
        mesh_name = f"turn_{turn:02d}_half_{ihalf}"
        mesh_o3d, _ = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
          point_cloud, depth=8)
        mesh_tmp_path = f"{tmp_dir}/{mesh_name}.ply"
        o3d.io.write_triangle_mesh(mesh_tmp_path, mesh_o3d)
        mesh = vtk_load_mesh_ply(mesh_tmp_path)
        mesh = clip_mesh(mesh, 0, 0, jz_start*500, 0, 0, 1)
        mesh = clip_mesh(mesh, 0, 0, jz_end*500, 0, 0, -1)
        mesh = clip_mesh(mesh, jx_split*500, 0, 0, -1 if ihalf == 0 else 1, 0, 0)
        vtk_save_mesh_stl(f"{out_dir}/{mesh_name}.stl", mesh)
