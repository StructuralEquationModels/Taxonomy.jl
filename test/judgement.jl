@testset "Judgment" begin
    @test J(1.3) == Judgement(1.3, 1.0)
    @test J(missing) == Judgement(missing, 1.0)
    @test convert(Judgement, 2.0) == Judgement(2.0, 1.0)
end