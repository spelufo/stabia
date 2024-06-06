import open3d as o3d
from stabia.core import *
from stabia.mesh_utils import *

def main(*mesh_paths):
  for path in mesh_paths:
    _, filename = path.rsplit("/", 1)
    mesh_name, ext = filename.rsplit(".", 1)
    if ext.lower() in ("ply", "obj", "stl"):
      o3d_mesh_report(o3d.io.read_triangle_mesh(path), mesh_name)
