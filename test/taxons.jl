using Taxonomy
using Test

mylgcm_sparse = LGCM(timecoding = [0,1,2,3,4])
mylgcm = LGCM(timecoding = [0,1,2,3,4], ntimepoints = 5, npredictors = 0, nonlinearfunction = 0)

@testset "LGCM" begin
    @test mylgcm.ntimepoints.rating == mylgcm_sparse.ntimepoints.rating == 5
end
