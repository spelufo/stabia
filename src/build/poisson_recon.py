from pathlib import Path
import numpy as np
import os
import open3d
import tempfile
import vtk

def mkdir(path):
  if not Path(path).is_dir():
    os.mkdir(path)

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

def poisson_recon(point_cloud):
  return open3d.geometry.TriangleMesh.create_from_point_cloud_poisson(point_cloud, depth=6)

def default_input_filter(filename):
  return filename.endswith(".ply") and f"sadj_fronts_" in filename

def default_output_namer(filename):
  return filename.replace(f"sadj_fronts", "sadj_chunk_recon")[:-4]

def poisson_recon_point_clouds(
    cell_dir,
    input_subdir="sadjs", output_subdir="chunks_recon",
    input_filter=default_input_filter, output_namer=default_output_namer
  ):
  cell_name = cell_dir.name
  cell_prefix = "cell_yxz_"
  assert cell_name.startswith(cell_prefix), "not a cell directory"
  cell = tuple(map(int, cell_name.removeprefix(cell_prefix).split("_")))
  in_dir = cell_dir / input_subdir
  out_dir = cell_dir / output_subdir
  mkdir(out_dir)
  with tempfile.TemporaryDirectory() as tmp_dir:
    for filename in os.listdir(in_dir):
      if input_filter(filename):
        print("Poisson reconstructing", filename)
        mesh_name = output_namer(filename)
        point_cloud = open3d.io.read_point_cloud(str(in_dir / filename))
        mesh_o3d, densities = poisson_recon(point_cloud)
        mesh_tmp_path = f"{tmp_dir}/{mesh_name}.ply"
        open3d.io.write_triangle_mesh(mesh_tmp_path, mesh_o3d)
        mesh = vtk_load_mesh_ply(mesh_tmp_path)
        mesh = crop_mesh_to_cell(mesh, cell)
        vtk_save_mesh_stl(f"{out_dir}/{mesh_name}.stl", mesh)

if __name__ == '__main__':
  import sys
  cell_dir = Path(sys.argv[1])
  poisson_recon_point_clouds(cell_dir)
