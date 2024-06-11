import os
import shutil
from pathlib import Path
import argparse
import numpy as np
import open3d as o3d
from PIL import Image; Image.MAX_IMAGE_PIXELS = None
from stabia.mesh_utils import o3d_mesh_report


def gen_mtl(texture_path):
	return f"""newmtl default
Ka 1.0 1.0 1.0
Kd 1.0 1.0 1.0
Ks 0.0 0.0 0.0
illum 2
d 1.0
map_Kd {texture_path}
"""

def mesh_texture_init(obj_input_path, obj_output_path, texture_suffix=".png"):
	mesh_name = os.path.splitext(os.path.basename(obj_input_path))[0]
	mesh = o3d.io.read_triangle_mesh(obj_input_path)

	# Compute the texture size from the mesh surface area.
	A = mesh.get_surface_area()
	uvs = np.asarray(mesh.triangle_uvs)
	uv_min = np.min(uvs, axis=0)
	uv_max = np.max(uvs, axis=0)
	uv_rect = (uv_max - uv_min)
	uvs_by_triangle = uvs.reshape(-1, 3, 2)
	p1 = uvs_by_triangle[:, 0, :]
	p2 = uvs_by_triangle[:, 1, :]
	p3 = uvs_by_triangle[:, 2, :]
	A_uv = np.sum(0.5 * np.abs(np.cross(p2 - p1, p3 - p1)))
	s = np.sqrt(A/A_uv)
	# x_size, y_size = np.ceil(s*uv_rect)
	size = int(s)

	# Create the blank texture.
	texture_path = f"{obj_output_path[:-4]}{texture_suffix}"
	texture = np.ones((size, size), dtype=np.uint16) * 65535
	Image.fromarray(texture, mode='L').save(texture_path)

	# TODO:
	# Unfortunately o3d.io.write_triangle_mesh introduces non-manifold elements.
	# For now we leave the UVs as they are and generate square textures for which
	# the object UVs don't need to be modified since they have correct aspect ratio.
	# # Normalize the uvs to the unit square, which uv maps to the image rect.
	# uvs = (uvs - uv_min) / uv_rect
	# mesh.triangle_uvs = o3d.utility.Vector2dVector(uvs)
	# assert mesh.has_triangle_uvs(), "failed to set triangle uvs"
	# o3d.io.write_triangle_mesh(obj_output_path, mesh, write_triangle_uvs=False, write_vertex_normals=False, write_vertex_colors=False)
	shutil.copyfile(obj_input_path, obj_output_path)

	# Create the material.
	mtl_path = f"{obj_output_path[:-4]}.mtl"
	texture_filename = os.path.basename(texture_path)
	with open(mtl_path, 'w') as file:
		file.write(gen_mtl(texture_filename))


def main(out_dir, *obj_paths):
	out_dir = Path(out_dir)
	if not out_dir.is_dir():
		os.mkdir(out_dir)
	for obj_path in obj_paths:
		mesh_texture_init(obj_path, str(out_dir / os.path.basename(obj_path)))
