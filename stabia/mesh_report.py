import os
import open3d as o3d
from stabia.core import *
from stabia.mesh_utils import *

def main(*mesh_paths):
  for path in mesh_paths:
    filename = os.path.basename(path)
    mesh_name, ext = os.path.splitext(filename)
    if ext.lower() in (".ply", ".obj", ".stl"):
      o3d_mesh_report(o3d.io.read_triangle_mesh(path), mesh_name)
