# The idea is to fit a sheet by gradient descent.


# 2d rectangle - M -> 3d sheet
# Learn M.


sheet_fit_by_grad(P::Array{Float32, 3}) = begin

  sheet = Matrix{Vec3f}
  render(sheet, p) = minimum(dist(p_sheet, p) for p_sheet in sheet) < thickness
  measurement_error(sheet) = sum((render(sheet, p) - P[p])^2 for p in P)
  smoothness_error(sheet) = sum((norm(p - p')^2 - d^2)^2 for neighbors)
  curvature_error(sheet) = sum((norm(p - p')^2 - d^2)^2 for neighbors)

end







