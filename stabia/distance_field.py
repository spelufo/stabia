from pathlib import Path
import os
import h5py
import numpy as np
import open3d as o3d
from stabia.core import *

# This is about x7 faster than the open3d example stack+meshgrid way of building
# it, and I think the order of the points is better, theirs has y coord moving
# faster.
def point_grid(jx, jy, jz, L=500):
  points = np.zeros((L,L,L,3), dtype=np.float32)
  # TODO: Figure out how to vectorize these for loops, should be faster.
  for i in range(L):
    for j in range(L):
      points[:,i,j,0] = np.arange(L*(jx-1), L*jx)
  for i in range(L):
    for j in range(L):
      points[i,:,j,1] = np.arange(L*(jy-1), L*jy)
  for i in range(L):
    for j in range(L):
      points[i,j,:,2] = np.arange(L*(jz-1), L*jz)
  return points

def cell_df_name(jy, jx, jz):
  return cell_name(jy, jx, jz) + "_distance_field"

def build_distance_field(jy, jx, jz, chunks_dir_name="chunks_recon"):
  # TODO: Is it worth translating the meshes near zero for better/faster results?
  cell_dir = segmentation_cell_dir(jy, jx, jz)
  seg_chunks_dir = cell_dir / chunks_dir_name
  files = (filename for filename in os.listdir(seg_chunks_dir) if filename.endswith(".stl"))
  files = sorted(files) # Not necessary, but nice.
  scene = o3d.t.geometry.RaycastingScene()
  for file in files:
    path = seg_chunks_dir / file
    if not path.is_file():
      raise FileNotFoundError(path)
    mesh = o3d.io.read_triangle_mesh(str(path))
    mesh = o3d.t.geometry.TriangleMesh.from_legacy(mesh)
    scene.add_triangles(mesh)
  points = point_grid(jx, jy, jz)
  df = scene.compute_distance(points).numpy()
  # TODO: Don't save both, decide on a format. HDF5 could have faster reads.
  # Numpy npz is more easily readable from julia, compressed h5 has issues.
  with h5py.File(cell_dir / f"{cell_df_name(jy, jx, jz)}.h5", 'w') as f:
    f.create_dataset('df', data=df, chunks=(100,100,100), compression='gzip')
  np.savez_compressed(cell_dir / f"{cell_df_name(jy, jx, jz)}.npz", df=df)
  return df

def build_distance_fields(cells, chunks_dir_name="chunks_recon"):
  for jy, jx, jz in cells:
    print(f"Building distance field ({jy}, {jx}, {jz})...")
    build_distance_field(jy, jx, jz, chunks_dir_name=chunks_dir_name)

def main(*args):
  jy, jx, jz = map(int, args)
  build_distance_field(jy, jx, jz)
