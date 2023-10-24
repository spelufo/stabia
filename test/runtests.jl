include("../src/stabia.jl")

using Test


@testset "Quaternion look at" begin
    p = Vec3f(1, 1, 1)
    tgt = Vec3f(0, 0, 0)
    up = Vec3f(0, 0, 1)
    VM = lookat(p, tgt, up)
    VP = lookat_pose(p tgt, up)
    @test VM ≈ view_matrix(VP)
end
