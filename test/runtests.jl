include("../src/stabia.jl")

using Test


@testset "Quaternion look at" begin
  examples = [
    # This one works.
    (Vec3f(1, 1, 1), Vec3f(0, 0, 0), Vec3f(0, 0, 1)),

    # TODO: This one fails, see values below. Why?
    (Vec3f(0, 2, 0), Vec3f(0.5), Vec3f(0, 0, 1)),
  ]
  for (i, example) in enumerate(examples)
    p, tgt, up = example
    VM = lookat(p, tgt, up)
    VP = lookat_pose(p, tgt, up)
    @test VM ≈ view_matrix(VP)
  end
end


# Float32[
#   -0.9486 -0.3162  0.0000   0.6324;
#   -0.0953  0.2860  0.9534  -0.5720;
#   -0.3015  0.9045 -0.3015  -1.8090;
#   0.0 0.0 0.0 1.0
# ]

# Float32[
#   -0.9486 -0.0953 -0.3015   0.1906;
#   -0.3162  0.2860  0.9045  -0.5720;
#    0.0000  0.9534 -0.3015  -1.9069;
#   0.0 0.0 0.0 1.0
# ]
