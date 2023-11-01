include("../src/stabia.jl")

using Test

@testset "Angle between vectors" begin
  @test angle(Vec3f(1, 0, 0), Vec3f(0, 1, 0)) ≈ π/2
  @test angle(Vec3f(0, 1, 0), Vec3f(1, 0, 0)) ≈ -π/2
  @test angle(Vec3f(0, 1, 0), Vec3f(0, 0, 1)) ≈ π/2
  @test angle(Vec3f(0, 0, 1), Vec3f(1, 0, 0)) ≈ π/2
  @test angle(Vec3f(1, 0, 0), Vec3f(1, 1, 0)) ≈ π/4
  # for i = 1:50
  #   a = rand(Vec3f); b = rand(Vec3f)
  #   @test angle(a, b) ≈ -angle(b, a)
  # end
end

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


# The old eigenvalue lookat fails the test.
# Looks like they are transposes of each other.
# I've discontinued it regardless, 3d orbit was wonky past a certain range.

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


# The new rotation composition version also fails, with these differences:
# The first two rows are permuted and one of them is negated.
# TODO: Probably a sign difference or coord swap somewhere. Track down.

# [-0.707   0.707    0.0       0.0;
#  -0.408  -0.408    0.816     0.0;
#   0.577   0.577    0.577    -1.732;
#   0.0     0.0      0.0       1.0]

# [-0.408  -0.408    0.816     0.0;
#   0.707  -0.707    0.0       0.0;
#   0.577   0.577    0.577    -1.732;
#   0.0     0.0      0.0       1.0]


@testset "Curve normal to planes" begin
  p0 = Vec3f(0.5f0, 0f0, 0f0)
  n0 = Ey
  n1 = Ey
  π1 = Ey
  γ, p1 = curve_normal_to_planes(p0, n0, π1, n1)
  # @show γ
  @test p1 ≈ Vec3f(0.5f0, 1f0, 0f0)
end

@testset "Perps walk" begin
  p0 = Vec3f(0.5f0, 0f0, 0f0)
  perps = Perp[
    Perp(p0, 0f0),
    Perp(Ey, 0f0),
  ]
  walk = perps_walk(perps, p0, 1f0)
  @test walk[1].p ≈ p0
  @test walk[1].θ ≈ 0f0
  @test walk[2].p ≈ Vec3f(0.5f0, 1f0, 0f0)
  @test walk[2].θ ≈ 0f0
end
