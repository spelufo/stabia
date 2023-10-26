# stabia

Stabia is an editor for the [vesuvius challenge](https://scrollprize.org) scroll scans.


## Notes

- The unit of the world coordinate system is the millimeter.
- The scan occupies the octant with all positive dimensions (3d quadrant).
- Use Vec3f for vectors and positions.
- There are multiple layers of data with different lifetimes:
  - Scan raw data: Lots of it, read parts of it from disk on demand.
  - Scan derived data: Stuff like normals, expensive to compute, cached on disk.
  - The scene data: User's data, e.g segmentation meshes. Persists across reloads.
  - The editor state: Shares lifetime of the window. The most transient.

