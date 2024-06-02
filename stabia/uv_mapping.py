import math
import numpy as np
import open3d as o3d
import igl
from PIL import Image
from stabia.core import *
from stabia.mesh_utils import *

# Conclusion: We must have non-manifold meshes. Holes are not a problem as long
# as the mesh is manifold so we can fill them by triangulation. Better not to
# have them though, as the harsh angles of the triangulation might affect uv quality.

# This assumes the mesh has disc topology: a single component, a single boundary
# loop, no holes. Vesuvius-blender mesh cleanup command tries to make this so.
def build_uv_map(mesh, slim_energy_threshold=8.05, slim_max_iters=20, tex_size=10240, tex_padding=1, mesh_name="mesh", debug_ic_mesh=False):
  scale_factor = 0.01 # For better floating point precision. Can't hurt...
  vertices = np.asarray(mesh.vertices, dtype=np.float64) * scale_factor
  n_vertices = vertices.shape[0]
  triangles = np.asarray(mesh.triangles, dtype=np.int32)
  n_triangles = triangles.shape[0]
  # Compute initial uv map with LSCM on the unit circle.
  boundaries = igl.all_boundary_loop(triangles)
  assert len(boundaries) == 1, f"len(boundaries) == {len(boundaries)} != 1"
  boundary = np.array(boundaries.pop(0), dtype=np.int32)
  boundary_uvs = igl.map_vertices_to_circle(vertices, boundary)
  ok, uvs = igl.lscm(vertices, triangles, boundary, boundary_uvs)
  if not ok:
    return False, mesh, None
  slim = igl.SLIM(vertices, triangles, v_init=uvs, b=boundary, bc=boundary_uvs,
    energy_type=igl.SLIM_ENERGY_TYPE_SYMMETRIC_DIRICHLET, soft_penalty=0)
  slim_init_energy = slim.energy()
  print(f"slim_init_energy: {slim_init_energy}")
  mesh_debug_path = f"/tmp/{mesh_name}.obj"
  if not slim_init_energy < math.inf or debug_ic_mesh:
    mesh.triangle_uvs = o3d.utility.Vector2dVector(uvs[triangles.flatten()])
    assert mesh.has_triangle_uvs(), "failed to set triangle uvs"
    o3d.io.write_triangle_mesh(mesh_debug_path, mesh)
    if not slim_init_energy < math.inf:
      print(f"Initial slim energy is infinite, debug the uv map of {mesh_debug_path}")
      return False, mesh, None
  # Run SLIM.
  slim_energy = slim_init_energy
  slim_iters = 0
  while slim_energy > slim_energy_threshold and slim_iters < slim_max_iters:
    slim.solve(1)
    slim_energy = slim.energy()
    slim_iters += 1
    print(f"\rslim_energy: {slim_energy}\tslim_iters: {slim_iters}", end="")
  print(f"\rslim_energy: {slim_energy}\tslim_iters: {slim_iters}")
  uvs = slim.vertices()
  # Create a white texture for the uvs to uv map to.
  uv_min = np.min(uvs, axis=0)
  uv_max = np.max(uvs, axis=0)
  uv_rect = (uv_max - uv_min)
  uvs = (uvs - uv_min) / uv_rect
  tex_size = math.ceil(tex_size)
  if uv_rect[0] > uv_rect[1]:
    uv_height = tex_size * uv_rect[1] / uv_rect[0]
    tex_rect = np.array([tex_size, math.ceil(uv_height)])
    uvs *= np.array([1.0, uv_height/tex_rect[1]])
  else:
    uv_width = tex_size * uv_rect[0] / uv_rect[1]
    tex_rect = np.array([math.ceil(uv_width), tex_size])
    uvs *= np.array([uv_width/tex_rect[0], 1.0])
  tex_rect_padded = tex_rect + 2*tex_padding
  uvs *= tex_rect / tex_rect_padded
  uvs += tex_padding / tex_rect_padded
  # Update the mesh uvs and add a blank texture.
  mesh.triangle_uvs = o3d.utility.Vector2dVector(uvs[triangles.flatten()])
  assert mesh.has_triangle_uvs(), "failed to set triangle uvs"
  tex = np.full(np.flip(tex_rect), 42000, dtype=np.uint16)
  mesh.textures = [o3d.geometry.Image(tex)]
  return True, mesh, tex

def build_uvs_for_file(input_path, output_path, debug_ic_mesh=False):
  mesh = o3d.io.read_triangle_mesh(input_path)
  mesh_dir, mesh_filename = input_path.rsplit("/", 1)
  mesh_name, _ = mesh_filename.rsplit(".", 1)
  ok, mesh, texture = build_uv_map(mesh, mesh_name=mesh_name, debug_ic_mesh=debug_ic_mesh)
  if ok:
    o3d.io.write_triangle_mesh(output_path, mesh)
    # Image.fromarray(texture, mode='L').save(f"{out_dir}/{out_name}.png")
    # with open(f"{out_dir}/{out_name}.mtl", "w+") as f:
    #   f.write("newmtl default\n")
    #   f.write("Ka 1.0 1.0 1.0\nKd 1.0 1.0 1.0\nKs 0.0 0.0 0.0\nillum 2.0\nd 1.0\n")
    #   f.write(f"map_Kd {out_name}.png\n")
  return ok

def build_uvs_for_files(out_dir, *input_paths, debug_ic_mesh=False):
  mkdir(out_dir)
  for input_path in input_paths:
    mesh_dir, mesh_filename = input_path.rsplit("/", 1)
    print(f"\nBuilding uvs for {mesh_filename} ...")
    out_filename = mesh_filename.replace(".ply", ".obj") # o3d doesn't support uvs on ply :(
    out_path = f"{out_dir}/{out_filename}"
    ok = build_uvs_for_file(input_path, out_path, debug_ic_mesh=debug_ic_mesh)
    if not ok:
      return
  print(f"\nAll done.")

# TODO: Preprocess with ACVD with a subprocess, so we don't have to remember to
# run it manually. From `recon_15/acvd`:
# ACVD ../cleaned/turn_??_h?.ply 400000 1 -s 2 -m 1 -of turn_??_h?_acvd.ply
# Each column (~500k vertices) takes ~7 min.

def main(out_dir, *input_paths):
  build_uvs_for_files(out_dir, *input_paths, debug_ic_mesh=True)
