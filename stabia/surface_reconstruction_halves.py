import json
import numpy as np
import open3d as o3d
import igl
from stabia.core import *
from stabia.mesh_utils import *
from stabia.uv_mapping import *

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

# TODO: It is too bad we can't snap the bouding box such that the poisson grid
# goes through the world axis. Because we don't control that there's a shift
# over which we don't have control. 
def create_from_point_cloud_poisson(pcd, depth=8, width=0, scale=1.1, **kwargs):
  # Work around open3d's poisson width bug:
  # https://github.com/isl-org/Open3D/issues/5842#issuecomment-2133275951
  if width > 0:
    depth = poisson_depth_from_width_and_scale(pcd, width, scale)
  return o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
    pcd, width=width, depth=depth, scale=scale, **kwargs
  )

def poisson_cleanup(mesh, densities):
  cis, cns, cas = mesh.cluster_connected_triangles()
  # print("component areas pre-cleanup:", cas)
  max_area = max(cas)
  # Any small value will remove the little bubble artifact components we are
  # after. For the assembly sheets, I expect a single big component. This can be
  # false when a umbilicus cell has a bit of sheet from the opposite half of the
  # turn. A higher value like max_area/2 will likely get rid of these too, which
  # is easier, but we will want to grab that component later to fill the hole
  # on the other half turn.
  max_allowed_area = max_area/3
  imax = 0
  remove_components = []
  for i, area in enumerate(cas):
    if area < max_allowed_area:
      remove_components.append(i)
    else:
      imax = i
  mesh.remove_triangles_by_mask([ci in remove_components for ci in cis])
  mesh.remove_unreferenced_vertices()
  # TODO: It would be nice to remove low density areas here, but we would need
  # to find a way to do it without creating non-manifold elements. Since we are
  # clipping at the winding boundaries it is not such a big deal not to. I will
  # do it manually in blender and it will be better for unfolding because I can
  # check the papyrus texture and delete bad segmentation areas at the top end
  # of the scroll while I'm at it. It took 2hs on GP segments.
  return mesh

def assemble_halves_meshes(out_dir, assembly_file, rm_tmp=True):
  # The poisson_width parameter determines the granularity / smoothness
  # of the result. Twice the superpixel width preserves the surface geometry
  # well while smoothing out the highest frequency kinks.
  poisson_width = 20 # d_spx is 10
  lz = 29
  mkdir(out_dir)
  mkdir(f"{out_dir}/tmp")
  with open(assembly_file, 'r') as f:
    turns_chunk_names = json.load(f)

  for turn, (turn_collection_name, turn_chunk_names) in enumerate(turns_chunk_names.items()):
    turn_name = f"turn_{turn:02d}"
    print(f"\nReconstructing {turn_name} (from {turn_collection_name})...")

    # Split the chunks between the two halves of the winding boundary.
    halves = [[], []]
    jz_range = [[lz+1, 0], [lz+1, 0]]
    for chunk_name in turn_chunk_names:
      jy, jx, jz, _, _ = parse_chunk_name(chunk_name)
      jx_split, jy_split = scroll_1_layer_ojs[jz]
      ihalf = int(jx <= jx_split)
      halves[ihalf].append(chunk_name)
      jz_range[ihalf][0] = min(jz_range[ihalf][0], jz-1)
      jz_range[ihalf][1] = max(jz_range[ihalf][1], jz)

    # Assemble each half.
    for ihalf, half in enumerate(halves):
      if len(half) == 0:
        continue

      # Load the chunk point clouds and run Poisson reconstruction to mesh them.
      point_cloud = o3d.geometry.PointCloud()
      for chunk_name in half:
        point_cloud += o3d.io.read_point_cloud(str(chunk_points_path(chunk_name)))
      half_name = f"{turn_name}_h{ihalf+1}"
      o3d.io.write_point_cloud(f"{out_dir}/tmp/{half_name}_points.ply", point_cloud)
      mesh_o3d, densities = create_from_point_cloud_poisson(point_cloud, width=poisson_width, linear_fit=True)
      o3d_mesh_report(mesh_o3d, f"{half_name}_p…")
      mesh_o3d = poisson_cleanup(mesh_o3d, densities)
      o3d_mesh_report(mesh_o3d, f"{half_name}_p…")
      mesh_poison_path = f"{out_dir}/tmp/{half_name}_poisson.ply"
      o3d.io.write_triangle_mesh(mesh_poison_path, mesh_o3d)
      if not mesh_o3d.is_vertex_manifold() or not mesh_o3d.is_edge_manifold():
        # Unfortunately PoissonRecon can result in nonmanifold geometry. The
        # problem has torus topology with a flattened union outside the bounds,
        # so luckily clipping will fix this one. TODO: Try vtk's Poisson.
        # It meshes with Delaunay which is nicer. Is it fast enough? Does it
        # guarantee manifold meshes?
        print(f"{half_name}_poisson is not manifold")

      # Use vtk to clip the meshes along the winding boundary.
      mesh = vtk_load(mesh_poison_path)
      # Clip the scroll bounds (just the z axis if fine for GP. TODO: x and y)
      mesh = clip_mesh(mesh, 0, 0, jz_range[ihalf][0]*500, 0, 0, 1)
      mesh = clip_mesh(mesh, 0, 0, jz_range[ihalf][1]*500, 0, 0, -1)
      # Split the mesh at z planes where the umbilicus (ojs) changes grid cell.
      meshes = []
      meshes_jzs = [[1, None]]
      meshes_ojs = [scroll_1_layer_ojs[1]]
      for jz in range(2, lz+1):
        if scroll_1_layer_ojs[jz] != scroll_1_layer_ojs[jz-1]:
          chopped, mesh = split_mesh(mesh, 0, 0, (jz-1)*500, 0, 0, 1)
          meshes.append(chopped)
          meshes_jzs[-1][1] = jz-1
          meshes_jzs.append([jz, None])
          meshes_ojs.append(scroll_1_layer_ojs[jz])
      meshes.append(mesh)
      meshes_jzs[-1][1] = lz
      assert len(meshes) == len(meshes_jzs) == len(meshes_ojs)
      # Split at the winding plane for each jzs range with a common one.
      for i, (mesh, jzs, ojs) in enumerate(zip(meshes, meshes_jzs, meshes_ojs)):
        jzs_start, jzs_end = jzs
        jx_split, jy_split = ojs
        mesh = clip_mesh(mesh, jx_split*500, 0, 0, 1 if ihalf == 0 else -1, 0, 0)
        meshes[i] = mesh
        # jzs_mesh_name = f"{half_name}_jzs_{jzs_start:02d}_{jzs_end:02d}"
        # if not vtk_mesh_is_empty(mesh):
        #   vtk_save(f"{out_dir}/jzs/{jzs_mesh_name}.ply", mesh)
        # else:
        #   print(f"{jzs_mesh_name} is empty.")
      mesh = merge_meshes(meshes)
      n_components, genus = vtk_mesh_report(mesh, half_name)
      vtk_mesh_path = f"{out_dir}/{half_name}.ply"
      vtk_save(vtk_mesh_path, mesh)
      if not vtk_is_edge_manifold(mesh):
        print(f"{half_name} is not edge manifold")

  if rm_tmp:
    shutil.rmtree(f"{out_dir}/tmp")

def main(*args):
  assemble_halves_meshes(*args, rm_tmp=False)
