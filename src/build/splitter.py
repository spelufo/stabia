import sys
import vtk

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
    res.append(chopped)
    if mesh.GetNumberOfCells() == 0 or mesh.GetNumberOfPoints() == 0:
      return res
  res.append(mesh)
  return res

def split_mesh_through_grid_planes(mesh, px, py, pz, lx, ly, lz, dx, dy, dz):
  res = []
  for layer in split_mesh_through_parallel_planes(mesh, px, py, pz, 0, 0, dz, lz+1):
    for strip in split_mesh_through_parallel_planes(layer, px, py, pz, 0, dy, 0, ly+1):
      for cell in split_mesh_through_parallel_planes(strip, px, py, pz, dx, 0, 0, lx+1):
        res.append(cell)
  return res

def split_mesh_through_simple_grid(mesh, lx, ly, lz, d):
  return split_mesh_through_grid_planes(mesh, 0, 0, 0, lx, ly, lz, d, d, d)

def splitter(filename):
  reader = vtk.vtkOBJReader()
  reader.SetFileName(filename)
  reader.Update()
  mesh = reader.GetOutput()
  comps = split_mesh_through_simple_grid(mesh, 50, 50, 50, 500)

  for i, mesh in enumerate(comps):
    writer_inside = vtk.vtkOBJWriter()
    writer_inside.SetFileName(f"component_{i}.obj")
    writer_inside.SetInputData(mesh)
    writer_inside.Write()


if __name__ == "__main__":
  if len(sys.argv) != 2:
    print("Usage:", sys.argv[0], "file.obj")
    exit(1)
  splitter(sys.argv[1])
