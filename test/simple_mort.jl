@testset "one  year" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5]),
            issue_age = 0
        ),
        InterestRate(0.05)
    )

    @test omega(ins) ≈ 1
    @test ä(ins) ≈ 1 + .5 / 1.05
    @test ä(ins,1) ≈ 1
    @test ä(ins,0) ≈ 0

    @test A(ins) ≈ 0.5 / 1.05
    @test A(ins,1) ≈ 0.5 / 1.05
    @test A(ins,0) ≈ 0


    ins_jl = LifeContingency(
        JointLife((ins.life,ins.life),LastSurvivor(),Frasier()),
        InterestRate(0.05)
    )

    @test omega(ins_jl) ≈ 1
    @test ä(ins_jl) ≈ 1 + .75 / 1.05
    @test ä(ins_jl,1) ≈ 1
    @test ä(ins_jl,0) ≈ 0

    @test survivorship(ins_jl,1) ≈ .5 + .5 - .5 * .5
    @test A(ins_jl) ≈ .25 / 1.05
    @test A(ins_jl,1) ≈ 0.25 / 1.05
    @test A(ins_jl,0) ≈ 0
end

@testset "two year" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5,0.5]),
            issue_age = 0
        ),
        InterestRate(0.05)
    )

    @test omega(ins) ≈ 2
    @test ä(ins) ≈ 1 + .5 * 1 / 1.05 + .25 / 1.05 ^2
    @test ä(ins,1) ≈ 1
    @test ä(ins,2) ≈ 1 + .5 * 1 / 1.05
    @test ä(ins,0) ≈ 0

    @test A(ins) ≈ 0.5 / 1.05 + 0.5 * 0.5 / 1.05 ^ 2
    @test A(ins,1) ≈ 0.5 / 1.05
    @test A(ins,0) ≈ 0

    ins_jl = LifeContingency(
        JointLife((ins.life,ins.life),LastSurvivor(),Frasier()),
        InterestRate(0.05)
    )

    @test survivorship(ins_jl,0) ≈ 1.0
    @test survivorship(ins_jl,1) ≈ .5 + .5 - .5 * .5
    @test survivorship(ins_jl,2) ≈ (.25 + .25 - .25 * .25)

end

@testset "two years" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5,0.5]),
            issue_age = 0
        ),
        InterestRate(0.05)
    )

    @test omega(ins) ≈ 2
    @test ä(ins,1) ≈ 1
    @test ä(ins,2) ≈ 1 + .5 * 1 / 1.05
    @test ä(ins,0) ≈ 0

    @test A(ins) ≈ 0.5 / 1.05 + 0.5 * 0.5 / 1.05 ^ 2
    @test A(ins,1) ≈ 0.5 / 1.05
    @test A(ins,0) ≈ 0

    ins_jl = LifeContingency(
        JointLife((ins.life,ins.life),LastSurvivor(),Frasier()),
        InterestRate(0.05)
    )

    @test omega(ins_jl) ≈ 2
    @test ä(ins_jl,1) ≈ 1
    @test ä(ins_jl,2) ≈ 1 + .75 /1.05
    @test ä(ins_jl,0) ≈ 0

end

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

    @test A(ins   ) ≈ 0.04223728223
    @test A(ins, 0) ≈ 0.0
    @test A(ins, 1) ≈ 0.0066571428571429
    @test ä(ins, 0) ≈ 0.0
    @test ä(ins, 1) ≈ 1.0

    @test A(ins, 30) ≈ 0.0137761089686975

    @test N(ins, 26) ≈ 5.156762988852310
    @test D(ins, 26) ≈ 0.275358702015970
    @test ä(ins, 26) ≈  14.9562540842669000 


end 