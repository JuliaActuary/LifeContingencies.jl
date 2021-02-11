@testset "basic building blocks" begin
    mt = UltimateMortality([0.5,0.5])

    # whole life insurance
    ins = Insurance(
            SingleLife(mort = mt,issue_age = 0),
            Yields.Constant(0.05)
    ) 

    @test all(survival(SingleLife(mort = mt,issue_age = 0)) .== [1.0, 0.5,0.25])

    @test timepoints(ins) == [1.0,2.0]
    @test survival(ins) == [1.0,0.5]
    @test discount(ins) == [1.0 / 1.05, 1 / 1.05^2]
    @test benefit(ins) == [1.0,1.0]
    @test probability(ins) == [0.5,0.25]
    @test cashflows(ins) == [0.5,0.25]
    @test cashflows(ins) == benefit(ins) .* probability(ins)
    @test present_value(ins)  ≈ 0.5 / 1.05 + 0.5 * 0.5 / 1.05 ^ 2
    @test present_value(ins) ≈ LifeContingencies.A(ins.life,ins.int)

    # basic life contingency tests
    @test survival(LifeContingency(ins),0,1) ≈ 0.5
    @test survival(LifeContingency(ins),0,2) ≈ 0.25
    @test discount(LifeContingency(ins),0,1) ≈ 1/1.05
    @test discount(LifeContingency(ins),0,2) ≈ 1/1.05^2

    # term life insurance
    ins = Insurance(
            SingleLife(mort = mt,issue_age = 0),
            Yields.Constant(0.05),
            n=1
    ) 

    @test survival(ins) == [1.0]
    @test discount(ins) == [1.0 / 1.05]
    @test benefit(ins) == [1.0]
    @test probability(ins) == [0.5]
    @test cashflows(ins) == [0.5]
    @test cashflows(ins) == benefit(ins) .* probability(ins)
    @test timepoints(ins) == [1.0]
    @test present_value(ins)  ≈ 0.5 / 1.05
    
    # annuity due
    ins = AnnuityDue(
            SingleLife(mort = mt,issue_age = 0),
            Yields.Constant(0.05)
    ) 

    @test survival(ins) == [1.0,0.5,.25]
    @test discount(ins) == [1.0, 1 / 1.05^1, 1 / 1.05^2]
    @test benefit(ins) == [1.0,1.0,1.0]
    @test timepoints(ins) == [0.0,1.0,2.0]  
    @test probability(ins) == [1.,0.5,0.25]
    @test cashflows(ins) == [1.0,0.5,0.25]
    @test cashflows(ins) == benefit(ins) .* probability(ins)
    @test present_value(ins)  ≈ 1 + 1 * .5 / 1.05 +  1 * .25 / 1.05 ^2

    ins = AnnuityDue(
        SingleLife(mort = mt,issue_age = 0),
        Yields.Constant(0.05),
        n = 2
) 
    @test present_value(ins)  ≈ 1 + 1 * .5 / 1.05

    ins = AnnuityImmediate(
        SingleLife(mort = mt,issue_age = 0),
        Yields.Constant(0.05),
        n = 1
    ) 

    @test present_value(ins)  ≈ 1 * .5 * 1 / 1.05

    ins = AnnuityDue(
        SingleLife(mort = mt,issue_age = 0),
        Yields.Constant(0.05),
        n = 1,
        start_time=1
    ) 

    @test timepoints(ins)  == [1.0]
    @test probability(ins)  == [0.5]
    @test present_value(ins)  ≈ 1 * .5 * 1 / 1.05

end

@testset "one  year" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5]),
            issue_age = 0
        ),
        Yields.Constant(0.05)
    )

    @test survival(ins,1) ≈ 0.5
    @test survival(ins,0) ≈ 1.0
    @test survival(ins.life,0,0.5) ≈ 1 - 0.5 * 0.5
    @test survival(ins,0.5) ≈ 1 - 0.5 * 0.5

    @test omega(ins) ≈ 1
    @test present_value(AnnuityDue(ins)) ≈ 1 + 1 * .5 / 1.05
    @test present_value(AnnuityDue(ins,n=1)) ≈ 1
    @test present_value(AnnuityDue(ins,n=0)) == 0
    @test present_value(AnnuityImmediate(ins,n=1)) ≈ 1 * .5 / 1.05
    @test present_value(AnnuityImmediate(ins,n=0)) == 0

    @test present_value(Insurance(ins)) ≈ 0.5 / 1.05
    @test present_value(Insurance(ins,n=1)) ≈ 0.5 / 1.05
    @test present_value(Insurance(ins,n=0)) ≈ 0


    ins_jl = LifeContingency(
        JointLife((ins.life,ins.life),LastSurvivor(),Frasier()),
        Yields.Constant(0.05)
    )

    @test omega(ins_jl) ≈ 1
    @test present_value(AnnuityDue(ins_jl)) ≈ 1 + 1 * .75 / 1.05
    @test present_value(AnnuityDue(ins_jl,n=1)) ≈ 1
    @test present_value(AnnuityImmediate(ins_jl,n=1)) ≈ 1 * .75 / 1.05
    @test present_value(AnnuityDue(ins_jl,n=2)) ≈ 1 + 1 * .75 / 1.05
    @test present_value(AnnuityDue(ins_jl,n=2;certain=2)) ≈ 1 + 1 / 1.05 
    @test present_value(AnnuityDue(ins_jl,n=0)) == 0

    @test survival(ins_jl,1) ≈ .5 + .5 - .5 * .5
    @test all(survival(JointLife((ins.life,ins.life),LastSurvivor(),Frasier())) .== [1.,.75])
    @test present_value(Insurance(ins_jl)) ≈ .25 / 1.05
    @test present_value(Insurance(ins_jl,n=1)) ≈ 0.25 / 1.05
    @test present_value(Insurance(ins_jl,n=0)) ≈ 0
end

@testset "two year no discount" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.0,0.0]),
            issue_age = 0
        ),
        Yields.Constant(0.00)
    )

    @test omega(ins) ≈ 2
    @test present_value(AnnuityDue(ins)) ≈ 3
    @test present_value(AnnuityDue(ins;start_time=1)) ≈ 2
    @test present_value(AnnuityDue(ins,n=1)) ≈ 1 
    @test present_value(AnnuityDue(ins,n=2)) ≈ 2
    @test_throws BoundsError present_value(AnnuityDue(ins,n=2;start_time=2))
    @test present_value(AnnuityDue(ins,n=3)) ≈ 3
    @test present_value(AnnuityDue(ins,n=0)) == 0
    @test present_value(AnnuityImmediate(ins,n=0)) == 0
    @test present_value(AnnuityImmediate(ins,n=1)) ≈ 1
    @test present_value(AnnuityImmediate(ins,n=1;start_time=1)) ≈ 1
    @test_throws BoundsError  present_value(AnnuityImmediate(ins;start_time=2))
    @test present_value(AnnuityImmediate(ins,n=2)) ≈ 2
    @test present_value(AnnuityImmediate(ins)) ≈ 2
    @test present_value(AnnuityImmediate(ins;certain=0)) ≈ 2
    @test present_value(AnnuityImmediate(ins;certain=2)) ≈ 2

    @test present_value(Insurance(ins)) ≈ 0
    @test present_value(Insurance(ins,n=1)) ≈ 0
    @test present_value(Insurance(ins,n=0)) ≈ 0

    ins_jl = LifeContingency(
        JointLife(
            lives = (ins.life,ins.life),
            contingency = LastSurvivor(),
            joint_assumption = Frasier()),
        Yields.Constant(0.00)
    )

    @test survival(ins_jl,0) ≈ 1.0
    @test survival(ins_jl,1) ≈ 1
    @test survival(ins_jl,2) ≈ 1

end

@testset "two year with interest" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5,0.5]),
            issue_age = 0
        ),
        Yields.Constant(0.05)
    )

    @test omega(ins) ≈ 2
    @test present_value(AnnuityDue(ins)) ≈ 1 + 1 * .5 * 1 / 1.05 +  1 * .25 / 1.05 ^2
    @test present_value(AnnuityDue(ins,n=1)) ≈ 1 
    @test present_value(AnnuityDue(ins,n=2)) ≈ 1 + 1 * .5 * 1 / 1.05
    @test present_value(AnnuityDue(ins,n=3)) ≈ 1 + 1 * .5 * 1 / 1.05 +  1 * .25 / 1.05 ^2
    @test present_value(AnnuityDue(ins,n=0)) ≈ 0
    @test present_value(AnnuityImmediate(ins,n=0)) ≈ 0
    @test present_value(AnnuityImmediate(ins,n=1)) ≈ 1 * .5 * 1 / 1.05

    @test present_value(Insurance(ins)) ≈ 0.5 / 1.05 + 0.5 * 0.5 / 1.05 ^ 2
    @test present_value(Insurance(ins,n=1)) ≈ 0.5 / 1.05
    @test present_value(Insurance(ins,n=0)) ≈ 0

    ins_jl = LifeContingency(
        JointLife(
            lives = (ins.life,ins.life),
            contingency = LastSurvivor(),
            joint_assumption = Frasier()),
        Yields.Constant(0.05)
    )

    @test survival(ins_jl,0) ≈ 1.0
    @test survival(ins_jl,1) ≈ .5 + .5 - .5 * .5
    @test survival(ins_jl,2) ≈ (.25 + .25 - .25 * .25)

end

@testset "two years" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5,0.5]),
            issue_age = 0
        ),
        Yields.Constant(0.05)
    )

    @test omega(ins) ≈ 2
    @test present_value(AnnuityDue(ins,n=1)) ≈ 1
    @test present_value(AnnuityDue(ins,n=2)) ≈ 1 + 1 * .5 * 1 / 1.05 
    @test present_value(AnnuityDue(ins,n=3)) ≈ 1 + 1 * .5 * 1 / 1.05 + 1 * .25 * 1 / 1.05 ^ 2
    @test present_value(AnnuityDue(ins,n=0)) == 0
    @test present_value(AnnuityImmediate(ins,n=0)) == 0
    @test present_value(AnnuityImmediate(ins,n=1)) ≈ 1 * .5 * 1 / 1.05 

    @test present_value(Insurance(ins)) ≈ 0.5 / 1.05 + 0.5 * 0.5 / 1.05 ^ 2
    @test present_value(Insurance(ins,n=1)) ≈ 0.5 / 1.05
    @test present_value(Insurance(ins,n=0)) ≈ 0

    ins_jl = LifeContingency(
        JointLife(
            lives = (ins.life,ins.life),
            contingency = LastSurvivor(),
            joint_assumption = Frasier()),
        Yields.Constant(0.05)
    )

    @test omega(ins_jl) ≈ 2
    @test present_value(AnnuityDue(ins_jl,n=1)) ≈ 1
    @test present_value(AnnuityDue(ins_jl,n=2)) ≈ 1 + 1 * .75 /1.05
    @test present_value(AnnuityDue(ins_jl,n=3)) ≈ 1 + 1 * .75 /1.05 + 1 * survival(ins_jl,2) / 1.05 ^ 2
    @test present_value(AnnuityDue(ins_jl,n=0)) == 0
    @test present_value(AnnuityImmediate(ins_jl,n=0)) == 0
    @test present_value(AnnuityImmediate(ins_jl,n=1)) ≈ 1 * .75 /1.05

end

# assumes embedded 'testMort' table in combination with MortalityTables
t = UltimateMortality(maleMort)

@testset "demo mortality" begin
    i = Yields.Constant(0.05)
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

    @test present_value(Insurance(ins   )) ≈ 0.04223728223
    @test present_value(Insurance(ins, n=0)) ≈ 0.0
    @test present_value(Insurance(ins, n=1)) ≈ 0.0066571428571429
    @test present_value(AnnuityDue(ins, n=0)) ≈ 0.0
    @test present_value(AnnuityDue(ins, n=1)) ≈ 1.0 
    @test present_value(AnnuityDue(ins, n=2)) ≈ 1.0 + survival(ins,1) / 1.05
    @test present_value(AnnuityImmediate(ins, n=0)) ≈ 0.0
    @test present_value(AnnuityImmediate(ins, n=1)) ≈ survival(ins,1) / 1.05

    @test present_value(Insurance(ins, n=30)) ≈ 0.0137761089686975

    @test N(ins, 26) ≈ 5.156762988852310
    @test D(ins, 26) ≈ 0.275358702015970
    @test present_value(AnnuityDue(ins, n=26)) ≈ 14.9562540842669



end 