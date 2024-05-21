import vtk

def vtk_load_mesh_ply(path):
  reader = vtk.vtkPLYReader()
  reader.SetFileName(path)
  reader.Update()
  return reader.GetOutput()

def vtk_save_mesh_stl(path, mesh):
  writer = vtk.vtkSTLWriter()
  writer.SetFileName(path)
  writer.SetInputData(mesh)
  writer.Write()

def clip_mesh(mesh, px, py, pz, nx, ny, nz):
  plane = vtk.vtkPlane()
  plane.SetOrigin(px, py, pz)
  plane.SetNormal(nx, ny, nz)
  clipper = vtk.vtkClipPolyData()
  clipper.SetInputData(mesh)
  clipper.SetClipFunction(plane)
  clipper.GenerateClippedOutputOn()
  clipper.Update()
  return clipper.GetOutput()

def crop_mesh_to_cell(mesh, cell):
  jy, jx, jz = cell
  x0, x1 = (jx-1)*500, jx*500
  y0, y1 = (jy-1)*500, jy*500
  z0, z1 = (jz-1)*500, jz*500
  mesh = clip_mesh(mesh, x0, y0, z0,  1,  0,  0)
  mesh = clip_mesh(mesh, x1, y0, z0, -1,  0,  0)
  mesh = clip_mesh(mesh, x0, y0, z0,  0,  1,  0)
  mesh = clip_mesh(mesh, x0, y1, z0,  0, -1,  0)
  mesh = clip_mesh(mesh, x0, y0, z0,  0,  0,  1)
  mesh = clip_mesh(mesh, x0, y0, z1,  0,  0, -1)
  return mesh

# Unfortunately, open3d doesn't do it right. It just removes vertices outside.
def crop_mesh_to_cell_open3d(mesh, cell):
  jy, jx, jz = cell
  p0 = np.array([jx-1, jy-1, jz-1])*500.0
  p1 = np.array([jx, jy, jz])*500.0
  return mesh.crop(open3d.geometry.AxisAlignedBoundingBox(p0, p1))
