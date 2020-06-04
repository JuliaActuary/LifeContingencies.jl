# assumes embedded 'testMort' table in combination with MortalityTables
include("test_mortality.jl")
t = UltimateMortality(maleMort)

@testset "demo mortality" begin
    i = InterestRate(0.05)
    ins = LifeContingency(SingleLife(mort = t, issue_age = 0), i)

    @test l(ins, 0) ≈ 1.0
    @test l(ins, 1) ≈ 0.993010000000000
    @test l(ins, 2) ≈ 0.992566124530000

    @test D(ins, 0) ≈ 1.0
    @test D(ins, 1) ≈ 0.945723809523809
    @test D(ins, 2) ≈ 0.900286734267574

    @test N(ins, 0) ≈ 20.113017073119200
    @test N(ins, 1) ≈ 19.113017073119200
    @test N(ins, 2) ≈ 18.167293263595400

    @test C(ins, 0) ≈ 0.006657142857142910
    @test C(ins, 1) ≈ 0.000402608136054441
    @test C(ins, 2) ≈ 0.000258082197156658

    @test M(ins, 0) ≈ 0.0422372822324182
    @test M(ins, 1) ≈ 0.0355801393752753
    @test M(ins, 2) ≈ 0.0351775312392208

    @test A(ins, 0) ≈ 0.04223728223
    @test ä(ins, 0) ≈ 20.1130170731192000

    @test A(ins, 26, 1) ≈ 0.001299047619    # 1 year term ins
    @test A(ins, 26) ≈ 0.1082172434         # whole life ins

    @test N(ins, 26) ≈ 5.156762988852310
    @test D(ins, 26) ≈ 0.275358702015970
    @test ä(ins, 26) ≈ 18.7274378877383000

end