import vtk
import numpy as np


def vtk_load(path):
  _, ext = path.rsplit(".", 1)
  Reader = getattr(vtk, f"vtk{ext.upper()}Reader")
  reader = Reader()
  reader.SetFileName(path)
  reader.Update()
  return reader.GetOutput()

def vtk_save(path, mesh):
  _, ext = path.rsplit(".", 1)
  Writer = getattr(vtk, f"vtk{ext.upper()}Writer")
  writer = Writer()
  writer.SetFileName(path)
  writer.SetInputData(mesh)
  writer.Write()

def vtk_mesh_is_empty(mesh):
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

def merge_meshes(meshes, tolerance=None):
  appender = vtk.vtkAppendPolyData()
  for mesh in meshes:
    appender.AddInputData(mesh)
  appender.Update()
  cleaner = vtk.vtkCleanPolyData()
  if tolerance is not None:
    cleaner.SetToleranceIsAbsolute(True)
    cleaner.SetTolerance(float(tolerance))
  cleaner.SetInputConnection(appender.GetOutputPort())
  cleaner.Update()
  return cleaner.GetOutput()

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


def o3d_mesh_report(mesh, name):
  import networkx
  _, _, cas = mesh.cluster_connected_triangles()
  n_components = len(cas)
  X = mesh.euler_poincare_characteristic()
  nonmanifold_edges = mesh.get_non_manifold_edges(allow_boundary_edges=True)
  boundary_edges = mesh.get_non_manifold_edges(allow_boundary_edges=False)
  n_boundary_edges = len(boundary_edges) - len(nonmanifold_edges)
  g = networkx.Graph()
  g.add_edges_from(boundary_edges)
  n_boundary_loops = networkx.number_connected_components(g)
  genus =  1 - (X + n_boundary_loops*n_components)/2
  print(name,
    "\tn_vertices:", len(mesh.vertices),
    "\tn_triangles:", len(mesh.triangles),
    "\tn_components:", n_components,
    "\tareas:", list(map(round, cas)) if n_components < 10 else "[...]",
    "\tgenus:", genus,
    "\tn_boundary_edges:", n_boundary_edges,
    "\tn_boundary_loops:", n_boundary_loops,
    "\tX:", X)


def vtk_mesh_report(mesh, name):
  n_vertices = mesh.GetNumberOfPoints()

  polys = mesh.GetPolys()
  polys.InitTraversal()
  n_triangles = 0
  id_list = vtk.vtkIdList()
  while polys.GetNextCell(id_list):
    n_triangles += 1

  boundary_edges = vtk.vtkFeatureEdges()
  boundary_edges.BoundaryEdgesOn()
  boundary_edges.FeatureEdgesOff()
  boundary_edges.NonManifoldEdgesOff()
  boundary_edges.ManifoldEdgesOff()
  boundary_edges.SetInputData(mesh)
  boundary_edges.Update()
  n_boundary_edges = boundary_edges.GetOutput().GetNumberOfLines()

  boundary_loops_filter = vtk.vtkPolyDataConnectivityFilter()
  boundary_loops_filter.SetInputData(boundary_edges.GetOutput())
  boundary_loops_filter.SetExtractionModeToAllRegions()
  boundary_loops_filter.Update()
  n_boundary_loops = boundary_loops_filter.GetNumberOfExtractedRegions()

  vtk.vtkLogger.SetStderrVerbosity(vtk.vtkLogger.VERBOSITY_WARNING)
  edges = vtk.vtkExtractEdges()
  edges.SetUseAllPoints(True)
  edges.SetInputData(mesh)
  edges.Update()
  n_edges = edges.GetOutput().GetNumberOfLines()

  mass_props = vtk.vtkMultiObjectMassProperties()
  mass_props.SetInputData(mesh)
  mass_props.Update()
  n_components = mass_props.GetNumberOfObjects()
  area = round(mass_props.GetTotalArea())

  X = n_vertices + n_triangles - n_edges
  genus =  1 - (X + n_boundary_loops*n_components)/2

  print(name,
    "\tn_vertices:", n_vertices,
    "\tn_triangles:", n_triangles,
    "\tn_components:", n_components,
    "\tarea :", [area],
    "\tgenus:", genus,
    "\tn_boundary_edges:", n_boundary_edges,
    "\tn_boundary_loops:", n_boundary_loops,
    "\tX:", X)

  return n_components, genus


def vtk_is_edge_manifold(mesh):
  f = vtk.vtkFeatureEdges()
  f.SetInputData(mesh)
  f.BoundaryEdgesOff()
  f.FeatureEdgesOff()
  f.NonManifoldEdgesOn()
  f.ManifoldEdgesOff()
  f.Update()
  return f.GetOutput().GetNumberOfCells() == 0


# This can probably introduce non-manifoldness.
# def o3d_mesh_cleanup(mesh):
#   mesh.remove_non_manifold_edges()
#   mesh.merge_close_vertices(0.001) # in what coords? We can increase this to avoid thin triangles, probably
#   mesh.remove_duplicated_vertices()
#   mesh.remove_duplicated_triangles()
#   mesh.remove_unreferenced_vertices()
#   mesh.remove_degenerate_triangles()
#   mesh.orient_triangles()
#   mesh = o3d_keep_largest_component(mesh)
#   return mesh
