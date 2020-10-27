# tests based on AMLCR 2nd ed,
@testset "AMLCR Math" begin

    # §5.7 payment frequency and certain (Tables 5.1 and 5.2)
    function f(age)
        ins = LifeContingency(SingleLife(mort = AMLCR_std, issue_age = age), Yields.Constant(0.05))
        [
            annuity_immediate(ins)
            annuity_immediate(ins,frequency=4)
            annuity_due(ins)
            annuity_due(ins,frequency=4)
            annuity_immediate(ins,10)
            annuity_immediate(ins,10,frequency=4)
            annuity_due(ins,10,frequency=4)
    ]
    end

    # atol only to two decimals b/c AMLCR uses rounded rates?
    @test all(isapprox.(f(20), [18.966, 19.338, 19.966, 19.588, 7.711, 7.855, 7.952],atol=.01))
    @test all(isapprox.(f(80), [ 7.548,  7.917,  8.548,  8.167, 6.128, 6.373, 6.539],atol=.01))

    ins = LifeContingency(SingleLife(mort = AMLCR_std, issue_age = 20), Yields.Constant(0.05))

    # property tests

    @test annuity_due(ins) > annuity_due(ins,start_time=5)

    @test annuity_due(ins,10,certain=10,start_time=5) == sum([1 for t in 5:9] .* [1/1.05 ^t for t in 5:9])
    
    # relation on pg 124
    @test issorted([
        annuity_immediate(ins) 
        annuity_immediate(ins,frequency=4) 
        annuity_due(ins,frequency=4)
        annuity_due(ins) 
    ])

end#