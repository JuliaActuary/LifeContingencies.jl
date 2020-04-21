using ActuarialScience
using Test
import Distributions: Normal
using MortalityTables

# assumes embedded 'testMort' table in combination with MortalityTables
include("test_mortality.jl")
t = UltimateMortality(maleMort)

################
# Interest Rates
################
@testset "interest rates" begin

    ## functional interest rate
    @testset "functional interest rate" begin
        i1 = InterestRate(time -> 0.05)

        @test 1 / (1.05) == v(i1)
        @test 1 / (1.05) == vx(i1, 1)
        @test 1 / (1.05^2) == tvx(i1, 2, 1)
        @test 0.05 == rate(i1, 1)
    end

    ## vector interest rate
    @testset "vector interest rate" begin
        i2 = InterestRate([0.05, 0.05, 0.05])
        @test 1 / (1.05) == v(i2)
        @test 1 / (1.05) == vx(i2, 1)
        @test 1 / (1.05^2) == tvx(i2, 2, 1)
    end

    ## real interest rate
    @testset "constant interest rate" begin
        i3 = InterestRate(0.05)

        @test 1 / (1.05) == v(i3)
        @test 1 / (1.05) == vx(i3, 1)
        @test 1 / (1.05^2) == tvx(i3, 2, 1)
        @test 1 / (1.05^120) ≈ tvx(i3, 120, 1)
    end

    ## Stochastic interest rate
    @testset "stochastic interest rate" begin
        i4 = InterestRate((x -> rand(Normal(0.05, 0.01))))
        # auto-correlated interest rate
        i5 = InterestRate(
            time -> time <= 1 ? 0.05 : rand(Normal(last(i5.rate_vector), 0.01)),
        )

        @test v(i4) > 0
        @test v(i5) > 0
        @test tvx(i4, 120, 1) > 0
        @test tvx(i5, 120, 1) > 0
    end
end

## Insurance
@testset "Insurance" begin
    i = InterestRate(0.05)
    ins = LifeContingency(t, i, 0)

    @test lx(ins, 0) ≈ 1.0
    @test lx(ins, 1) ≈ 0.993010000000000
    @test lx(ins, 2) ≈ 0.992566124530000

    @test Dx(ins, 0) ≈ 1.0
    @test Dx(ins, 1) ≈ 0.945723809523809
    @test Dx(ins, 2) ≈ 0.900286734267574

    @test Nx(ins, 0) ≈ 20.113017073119200
    @test Nx(ins, 1) ≈ 19.113017073119200
    @test Nx(ins, 2) ≈ 18.167293263595400

    @test Cx(ins, 0) ≈ 0.006657142857142910
    @test Cx(ins, 1) ≈ 0.000402608136054441
    @test Cx(ins, 2) ≈ 0.000258082197156658

    @test Mx(ins, 0) ≈ 0.0422372822324182
    @test Mx(ins, 1) ≈ 0.0355801393752753
    @test Mx(ins, 2) ≈ 0.0351775312392208

    @test Ax(ins, 0) ≈ 0.04223728223

    @test Axn(ins, 26, 1) ≈ 0.001299047619
    @test Ax(ins, 26) ≈ 0.1082172434
    @test äx(ins, 26) >= 0.0
end

## TODO: more robust tests because current calculations are probably off
