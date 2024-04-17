import os
from pathlib import Path
import sys
import vtk

def mkdir(path):
  if not Path(path).is_dir():
    os.mkdir(path)

def mesh_is_empty(mesh):
  return mesh.GetNumberOfCells() == 0 or mesh.GetNumberOfPoints() == 0

def split_components(mesh):
  res = []
  conn = vtk.vtkConnectivityFilter()
  conn.SetInputData(mesh)
  conn.SetExtractionModeToAllRegions()
  conn.ColorRegionsOn()
  conn.Update()
  sel = vtk.vtkThreshold()
  sel.SetInputArrayToProcess(0, 0, 0, 0, "RegionId")
  sel.SetInputConnection(conn.GetOutputPort())
  sel.AllScalarsOff()
  for i in range(conn.GetNumberOfExtractedRegions()):
    sel.SetLowerThreshold(i)
    sel.SetUpperThreshold(i)
    geom = vtk.vtkGeometryFilter()
    geom.SetInputConnection(sel.GetOutputPort())
    geom.Update()
    res.append((i+1, geom.GetOutput()))
  return res

def split_mesh(mesh, px, py, pz, nx, ny, nz):
  plane = vtk.vtkPlane()
  plane.SetOrigin(px, py, pz)
  plane.SetNormal(nx, ny, nz)
  clipper = vtk.vtkClipPolyData()
  clipper.SetInputData(mesh)
  clipper.SetClipFunction(plane)
  clipper.GenerateClippedOutputOn()
  clipper.Update()
  return clipper.GetClippedOutput(), clipper.GetOutput()

def split_mesh_through_parallel_planes(mesh, px, py, pz, nx, ny, nz, num_splits):
  # NOTE: We don't split at the endpoints of the range. Makes composition nicer.
  assert num_splits >= 0, "num_splits cannot be negative"
  res = []
  for i in range(1, num_splits+1):
    chopped, mesh = split_mesh(mesh, px + i*nx, py + i*ny, pz + i*nz, nx, ny, nz)
    if not mesh_is_empty(chopped):
      res.append((i, chopped))
    if mesh_is_empty(mesh):
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

def save_mesh_stl(mesh, path):
  writer = vtk.vtkSTLWriter()
  writer.SetFileName(path)
  writer.SetInputData(mesh)
  writer.Write()

def split_segment(segment_obj, segmentation_dir, umbilicus):
  segid = Path(segment_obj).stem

  # print("Loading...")
  reader = vtk.vtkOBJReader()
  reader.SetFileName(segment_obj)
  reader.Update()
  mesh = reader.GetOutput()
  dx = dy = dz = 500
  lx = ly = lz = 50

  def save_split_mesh(mesh, jx, jy, jz, ihalf, i):
    cell_name = f"cell_yxz_{jy:03d}_{jx:03d}_{jz:03d}"
    cell_dir = segmentation_dir / cell_name
    mkdir(cell_dir)
    splits_dir = cell_dir / "splits"
    mkdir(splits_dir)
    save_mesh_stl(mesh, splits_dir / f"{cell_name}_split_{segid}_{ihalf}_{i:02d}.stl")

  # print("Splitting...")
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
      for (jx, jy, _), mesh in split_mesh_through_xy_grid_planes(component, 0, 0, pz, lx_half, ly, dx, dy, jz):
        save_split_mesh(mesh, jx, jy, jz, 0, i)
    for (i, component) in split_components(layer_half_1):
      for (jx, jy, _), mesh in split_mesh_through_xy_grid_planes(component, px, 0, pz, lx - lx_half, ly, dx, dy, jz):
        save_split_mesh(mesh, jx + lx_half, jy, jz, 1, i)


def split_segments(volpkg_dir, segment_ids, umbilicus):
  assert volpkg_dir.is_dir(), "VOLPKG_DIR must be a directory"
  segmentation_dir = volpkg_dir / "segmentation"
  mkdir(segmentation_dir)
  for segid in segment_ids:
    print("Splitting segment ", segid)
    split_segment(volpkg_dir / "paths" / segid / f"{segid}.obj", segmentation_dir, umbilicus)


################################################################################

gp_segments = [
  "20230929220926",
  "20231005123336",
  "20231007101619",
  "20231210121321",
  "20231012184424",
  "20231022170901",
  "20231221180251",
  "20231106155351",
  "20231031143852",
  "20230702185753",
  "20231016151002",
]

umbilicus = [
  (4079, 2443, 250),
  (4070, 2367, 750),
  (4081, 2327, 1250),
  (4038, 2300, 1750),
  (3978, 2240, 2250),
  (3853, 2181, 2750),
  (3730, 2196, 3250),
  (3803, 2211, 3750),
  (3827, 2247, 4250),
  (3785, 2377, 4750),
  (3795, 2551, 5250),
  (3852, 2868, 5750),
  (3884, 3282, 6250),
  (3776, 3485, 6750),
  (3721, 3535, 7250),
  (3649, 3524, 7750),
  (3547, 3498, 8250),
  (3471, 3490, 8750),
  (3393, 3480, 9250),
  (3365, 3596, 9750),
  (3288, 3690, 10250),
  (3199, 3782, 10750),
  (3085, 3917, 11250),
  (2976, 4017, 11750),
  (2978, 4185, 12250),
  (2963, 4387, 12750),
  (2879, 4627, 13250),
  (2879, 4627, 13750),
]

def main(volpkg_dir):
  # We could do something like this to get all of them, but some are old versions,
  # we'll need a whitelist of some sort.
  # segment_ids = os.listdir(volpkg_dir / "paths")
  # For now hardcoding the gp segments.
  split_segments(volpkg_dir, gp_segments, umbilicus)

if __name__ == "__main__":
  if len(sys.argv) != 2:
    print("Usage:", sys.argv[0], "VOLPKG_DIR")
    exit(1)
  main(Path(sys.argv[1]))
