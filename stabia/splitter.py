import os
from pathlib import Path
import sys
import vtk
from stabia.core import *
from stabia.mesh_utils import *

def split_mesh_through_parallel_planes(mesh, px, py, pz, nx, ny, nz, num_splits):
  # NOTE: We don't split at the endpoints of the range. Makes composition nicer.
  assert num_splits >= 0, "num_splits cannot be negative"
  res = []
  for i in range(1, num_splits+1):
    chopped, mesh = split_mesh(mesh, px + i*nx, py + i*ny, pz + i*nz, nx, ny, nz)
    if not vtk_mesh_is_empty(chopped):
      res.append((i, chopped))
    if vtk_mesh_is_empty(mesh):
      return res
  res.append((num_splits+1, mesh))
  return res

def split_mesh_through_xy_grid_planes(mesh, px, py, pz, lx, ly, dx, dy, jz):
  res = []
  for jy, strip in split_mesh_through_parallel_planes(mesh, px, py, pz, 0, dy, 0, ly-1):
    for jx, cell in split_mesh_through_parallel_planes(strip, px, py, pz, dx, 0, 0, lx-1):
      res.append(((jx, jy, jz), cell))
  return res

def split_mesh_through_grid_planes(mesh, px, py, pz, lx, ly, lz, dx, dy, dz):
  res = []
  for jz, layer in split_mesh_through_parallel_planes(mesh, px, py, pz, 0, 0, dz, lz-1):
    res += split_mesh_through_xy_grid_planes(mesh, px, py, pz, lx, ly, dx, dy, jz)
  return res

def split_mesh_through_simple_grid(mesh, lx, ly, lz, d):
  return split_mesh_through_grid_planes(mesh, 0, 0, 0, lx, ly, lz, d, d, d)

def split_segment_into_cell_chunks(segment_obj, segmentation_dir, umbilicus):
  segid = Path(segment_obj).stem
  mesh = vtk_load(segment_obj)
  dx = dy = dz = 500
  lx = ly = lz = 50

  def save_split_chunk(chunk, jx, jy, jz, ihalf, i):
    cell_name = f"cell_yxz_{jy:03d}_{jx:03d}_{jz:03d}"
    cell_dir = segmentation_dir / cell_name
    mkdir(cell_dir)
    chunks_dir = cell_dir / "chunks"
    mkdir(chunks_dir)
    vtk_save(chunk, chunks_dir / f"{cell_name}_chunk_{segid}_{ihalf}_{i:02d}.stl")

  # 1. Split on z grid.
  # 2. Split each layer on x at grid boundary closest to umbilicus(jz).
  # 3. Separate components. Will result in one component per half winding.
  # 4. Split on y grid.
  for jz, layer in split_mesh_through_parallel_planes(mesh, 0, 0, 0, 0, 0, dz, lz+1):
    if jz < 1 or jz > len(umbilicus):
      print("jz oob", jz)
      continue
    px, py, pz = umbilicus[jz-1]
    lx_half = round(px/dz)
    px = lx_half*dz
    layer_half_0, layer_half_1 = split_mesh(layer, px, py, pz, dx, 0, 0)
    for (i, component) in split_components(layer_half_0):
      for (jx, jy, _), chunk in split_mesh_through_xy_grid_planes(component, 0, 0, pz, lx_half, ly, dx, dy, jz):
        save_split_chunk(chunk, jx, jy, jz, 0, i)
    for (i, component) in split_components(layer_half_1):
      for (jx, jy, _), chunk in split_mesh_through_xy_grid_planes(component, px, 0, pz, lx - lx_half, ly, dx, dy, jz):
        save_split_chunk(chunk, jx + lx_half, jy, jz, 1, i)


def split_segment_into_layer_rings(segment_obj, rings_dir, umbilicus):
  segid = Path(segment_obj).stem
  mesh = vtk_load(segment_obj)
  dx = dy = dz = 500
  lx = ly = lz = 50

  def save_split_ring(ring, jz, ihalf, i):
    layer = f"layer_jz_{jz:03d}"
    layer_dir = rings_dir / layer
    mkdir(layer_dir)
    vtk_save(ring, layer_dir / f"{layer}_ring_{segid}_{ihalf}_{i:02d}.stl")

  for jz, layer in split_mesh_through_parallel_planes(mesh, 0, 0, 0, 0, 0, dz, lz+1):
    if jz < 1 or jz > len(umbilicus):
      print("jz oob", jz)
      continue
    px, py, pz = umbilicus[jz-1]
    lx_half = round(px/dz)
    px = lx_half*dz
    layer_half_0, layer_half_1 = split_mesh(layer, px, py, pz, dx, 0, 0)
    # TODO: It would be best to sort the components by winding number.
    # How? UVs? Raycast would work, but too much work / too expensive?
    for (i, ring) in split_components(layer_half_0):
      save_split_ring(ring, jz, 0, i)
    for (i, ring) in split_components(layer_half_1):
      save_split_ring(ring, jz, 1, i)

def split_segments_into_cell_chunks(volpkg_dir, segment_ids, umbilicus):
  assert volpkg_dir.is_dir(), "VOLPKG_DIR must be a directory"
  segmentation_dir = volpkg_dir / "segmentation"
  mkdir(segmentation_dir)
  for segid in segment_ids:
    print("Splitting segment ", segid)
    split_segment_into_cell_chunks(volpkg_dir / "paths" / segid / f"{segid}.obj", segmentation_dir, umbilicus)

def split_segments_into_layer_rings(volpkg_dir, segment_ids, umbilicus):
  assert volpkg_dir.is_dir(), "VOLPKG_DIR must be a directory"
  rings_dir = volpkg_dir / "rings"
  mkdir(rings_dir)
  for segid in segment_ids:
    print("Splitting segment ", segid)
    split_segment_into_layer_rings(volpkg_dir / "paths" / segid / f"{segid}.obj", rings_dir, umbilicus)

def main(volpkg_dir):
  # We could do something like this to get all of them, but some are old versions,
  # we'll need a whitelist of some sort.
  # segment_ids = os.listdir(volpkg_dir / "paths")
  # For now hardcoding the gp segments.
  split_segments_into_cell_chunks(volpkg_dir, gp_segments, scroll_1_umbilicus)
  # split_segments_into_layer_rings(volpkg_dir, gp_segments, scroll_1_umbilicus)
