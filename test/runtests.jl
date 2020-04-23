using LifeContingencies
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
    @testset "demo mortality" begin
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
        @test äx(ins, 0) ≈ 20.1130170731192000

        @test Axn(ins, 26, 1) ≈ 0.001299047619
        @test Ax(ins, 26) ≈ 0.1082172434

        @test Nx(ins,26) ≈ 5.156762988852310
        @test Dx(ins,26) ≈ 0.275358702015970
        @test äx(ins, 26) ≈ 18.7274378877383000

    end
    @testset "Mortality Tables mortality" begin
        tbls = MortalityTables.tables()
        @testset "issue age 116" begin
            t = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]
            i = InterestRate(0.05)
            issue_age = 116
            ins = LifeContingency(t.select, i, issue_age)


            @test lx(ins, 0) ≈ 1.0
            @test lx(ins, 1) ≈ 0.200120000000000
            @test lx(ins, 2) ≈ 0.030764447600000

            @test Dx(ins, 0) ≈ 1.0
            @test Dx(ins, 1) ≈ 0.190590476190476
            @test Dx(ins, 2) ≈ 0.027904260861678

            @test Nx(ins, 0) ≈ 1.221415195080500
            @test Nx(ins, 1) ≈ 0.221415195080502
            @test Nx(ins, 2) ≈ 0.030824718890026

            @test Cx(ins, 0) ≈ 0.761790476190476000
            @test Cx(ins, 1) ≈ 0.153610478367347000
            @test Cx(ins, 2) ≈ 0.023794627623916200

            @test Mx(ins, 0) ≈ 0.9418373716628330
            @test Mx(ins, 1) ≈ 0.1800468954723570
            @test Mx(ins, 2) ≈ 0.0264364171050101

            @test Ax(ins, 0) ≈ 0.9418373716628330
            @test äx(ins, 0) ≈ 1.2214151950805000

            @test Ax(ins, 3) ≈ 0.9499904761904760
            @test äx(ins, 3) ≈ 1.0502000000000000

        end

        @testset "issue age 30" begin
            t = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]
            i = InterestRate(0.05)
            issue_age = 30
            ins = LifeContingency(t.select, i, issue_age)


            @test lx(ins, 0) ≈ 1.0
            @test lx(ins, 1) ≈ 0.999670000000000
            @test lx(ins, 2) ≈ 0.999210151800000


            @test Dx(ins, 0) ≈ 1.0
            @test Dx(ins, 1) ≈ 0.952066666666667
            @test Dx(ins, 2) ≈ 0.906313062857143


            @test Nx(ins, 0) ≈ 18.673525637928100
            @test Nx(ins, 1) ≈ 17.673525637928100
            @test Nx(ins, 2) ≈ 16.721458971261400

            @test Cx(ins, 0) ≈ 0.000314285714285764
            @test Cx(ins, 1) ≈ 0.000417095873015874
            @test Cx(ins, 2) ≈ 0.000474735413877510

            @test Mx(ins, 0) ≈ 0.1107844934319970
            @test Mx(ins, 1) ≈ 0.1104702077177110
            @test Mx(ins, 2) ≈ 0.1100531118446950

            @test Ax(ins, 0) ≈ 0.1107844934319970
            @test äx(ins, 0) ≈ 18.6735256379281000
            @test Px(ins, 0) ≈ 0.0059327036350854
            @test tVx(ins, 0,1) ≈ 0.0059012862412992
            @test tVx(ins, 0,2) ≈ 0.0119711961204193

            @test Ax(ins, 26) ≈ 0.3324580935487340
            @test äx(ins, 26) ≈ 14.0183800354766000
            @test Px(ins, 26) ≈ 0.0237158710712205

        end
    end
end
