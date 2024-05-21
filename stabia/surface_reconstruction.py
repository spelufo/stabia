from pathlib import Path
import numpy as np
import os
import open3d as o3d
import tempfile
from stabia.core import *
from stabia.mesh_utils import *


def poisson_recon(point_cloud):
  # return o3d.geometry.TriangleMesh.create_from_point_cloud_alpha_shape(point_cloud, 0.05)
  # return o3d.geometry.TriangleMesh.create_from_point_cloud_ball_pivoting(point_cloud, o3d.utility.DoubleVector([10.0, 15.0, 20.0, 50.0]))
  mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(point_cloud, depth=6)
  return mesh

# These segfault. Skip them. After adding one, delete the chunks_recon folder and rerun.
blacklist = [
  "cell_yxz_004_010_009_sadj_fronts_01_20231106155351103.ply",
  "cell_yxz_004_008_012_sadj_fronts_01_20231007101619002.ply",
  "cell_yxz_007_007_014_sadj_fronts_20_20231012184424005.ply",
  "cell_yxz_006_005_016_sadj_fronts_06_20231005123336001.ply",
  "cell_yxz_006_008_018_sadj_fronts_01_20231016151002104.ply",
  "cell_yxz_009_005_018_sadj_fronts_01_20230929220926003.ply",
  "cell_yxz_006_006_020_sadj_fronts_24_20230929220926003.ply",
  "cell_yxz_010_006_020_sadj_fronts_01_20231210121321001.ply",
  "cell_yxz_008_007_021_sadj_fronts_01_20230702185753002.ply",
  "cell_yxz_010_005_021_sadj_fronts_01_20231005123336001.ply",
  "cell_yxz_009_005_024_sadj_fronts_12_20231210121321001.ply",
  "cell_yxz_008_007_026_sadj_fronts_27_20231005123336103.ply",
  "cell_yxz_008_009_026_sadj_fronts_01_20230929220926102.ply",
  "cell_yxz_007_006_001_sadj_fronts_01_20231007101619002.ply",
]

def default_input_filter(filename):
  return filename.endswith(".ply") and f"sadj_fronts_" in filename and filename not in blacklist

def default_output_namer(filename):
  return filename.replace(f"sadj_fronts", "sadj_chunk_recon")[:-4]

def cell_from_name(cell_name):
  cell_prefix = "cell_yxz_"
  assert cell_name.startswith(cell_prefix), "invalid cell name: "+cell_name
  return tuple(map(int, cell_name.removeprefix(cell_prefix).split("_")))

def cell_from_dir(cell_dir):
  return cell_from_name(cell_dir.name)

def poisson_recon_point_clouds(
    cell_dir,
    input_subdir="sadjs", output_subdir="chunks_recon",
    input_filter=default_input_filter, output_namer=default_output_namer
  ):
  cell = cell_from_dir(cell_dir)
  in_dir = cell_dir / input_subdir
  out_dir = cell_dir / output_subdir
  if out_dir.is_dir():
    print(f"{out_dir.name} exists, skipping.")
    return
  mkdir(out_dir)
  with tempfile.TemporaryDirectory() as tmp_dir:
    for filename in sorted(os.listdir(in_dir)):
      if input_filter(filename):
        print("Poisson reconstructing", filename)
        mesh_name = output_namer(filename)
        point_cloud = o3d.io.read_point_cloud(str(in_dir / filename))
        mesh_o3d = poisson_recon(point_cloud)
        mesh_tmp_path = f"{tmp_dir}/{mesh_name}.ply"
        o3d.io.write_triangle_mesh(mesh_tmp_path, mesh_o3d)
        mesh = vtk_load_mesh_ply(mesh_tmp_path)
        mesh = crop_mesh_to_cell(mesh, cell)
        vtk_save_mesh_stl(f"{out_dir}/{mesh_name}.stl", mesh)

# if __name__ == '__main__':
#   import sys
#   cell_dir = Path(sys.argv[1])
#   poisson_recon_point_clouds(cell_dir)

def poisson_recon_point_clouds_layer(segmentation_dir, jz):
  for dirname in sorted(os.listdir(segmentation_dir)):
    if not dirname.startswith("cell_"):
      continue
    cell = cell_from_name(dirname)
    if cell[2] != jz:
      continue
    cell_dir = segmentation_dir / dirname
    if not (cell_dir / "sadjs").is_dir():
      continue
    print(f"\nPoisson reconstructing cell {cell}")
    poisson_recon_point_clouds(cell_dir)


if __name__ == '__main__':
  import sys
  segmentation_dir = Path(sys.argv[1])
  jz = int(sys.argv[2])
  poisson_recon_point_clouds_layer(segmentation_dir, jz)
