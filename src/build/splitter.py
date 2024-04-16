import os
from pathlib import Path
import sys
import vtk

def mkdir(path):
  if not Path(path).is_dir():
    os.mkdir(path)

def mesh_is_empty(mesh):
  return mesh.GetNumberOfCells() == 0 or mesh.GetNumberOfPoints() == 0

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
  # TODO: Recursive binary splitting may be more efficient. It would also
  # produce nicer triangulation.
  res = []
  for i in range(num_splits):
    chopped, mesh = split_mesh(mesh, px + i*nx, py + i*ny, pz + i*nz, nx, ny, nz)
    if not mesh_is_empty(chopped):
      res.append((i+1, chopped))
    if mesh_is_empty(mesh):
      return res
  res.append(mesh)
  return res

def split_mesh_through_grid_planes(mesh, px, py, pz, lx, ly, lz, dx, dy, dz):
  res = []
  for jz, layer in split_mesh_through_parallel_planes(mesh, px, py, pz, 0, 0, dz, lz+1):
    for jy, strip in split_mesh_through_parallel_planes(layer, px, py, pz, 0, dy, 0, ly+1):
      for jx, cell in split_mesh_through_parallel_planes(strip, px, py, pz, dx, 0, 0, lx+1):
        res.append(((jx, jy, jz), cell))
  return res

def split_mesh_through_simple_grid(mesh, lx, ly, lz, d):
  return split_mesh_through_grid_planes(mesh, 0, 0, 0, lx, ly, lz, d, d, d)

def split_components(mesh):
  res = []
  conn = vtk.vtkConnectivityFilter()
  conn.SetInputData(mesh)
  conn.SetExtractionModeToAllRegions()
  conn.ColorRegionsOn() # is this needed?
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


def split_segment(segment_obj, segmentation_dir):
  segid = Path(segment_obj).stem

  # print("Loading...")
  reader = vtk.vtkOBJReader()
  reader.SetFileName(segment_obj)
  reader.Update()
  mesh = reader.GetOutput()

  # print("Splitting...")
  meshes = split_mesh_through_simple_grid(mesh, 50, 50, 50, 500)

  # print("Saving components...")
  for (jx, jy, jz), mesh in meshes:
    cell_name = f"cell_yxz_{jy:03d}_{jx:03d}_{jz:03d}"
    cell_dir = segmentation_dir / cell_name
    mkdir(cell_dir)
    splits_dir = cell_dir / "splits"
    mkdir(splits_dir)
    for (i, component) in split_components(mesh):
      writer = vtk.vtkSTLWriter()
      writer.SetFileName(splits_dir / f"{cell_name}_split_{segid}_{i:02d}.stl")
      writer.SetInputData(component)
      writer.Write()

def split_segments(volpkg_dir, segment_ids):
  assert volpkg_dir.is_dir(), "VOLPKG_DIR must be a directory"
  segmentation_dir = volpkg_dir / "segmentation"
  mkdir(segmentation_dir)
  for segid in segment_ids:
    print("Splitting segment ", segid)
    split_segment(volpkg_dir / "paths" / segid / f"{segid}.obj", segmentation_dir)

def main(volpkg_dir):
  # We could do something like this to get all of them, but some are old versions,
  # we'll need a whitelist of some sort.
  # segment_ids = os.listdir(volpkg_dir / "paths")
  # For now hardcoding the gp segments.
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
  split_segments(volpkg_dir, gp_segments)


if __name__ == "__main__":
  if len(sys.argv) != 2:
    print("Usage:", sys.argv[0], "VOLPKG_DIR")
    exit(1)
  main(Path(sys.argv[1]))
