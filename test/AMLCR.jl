@testset "AMLCR Math" begin

    function f(age)
        ins = LifeContingency(SingleLife(mort = AMLCR_std, issue_age = age), Yields.Constant(0.05))
        [
            annuity_immediate(ins)
            annuity_immediate(ins,frequency=4)
            annuity_due(ins)
            annuity_due(ins,frequency=4)
    ]
    end


    @test all(isapprox.(f(20), [18.966,19.338,19.966,19.588],atol=.01))
    @test all(isapprox.(f(80), [7.548,7.917,8.548,8.167],atol=.01))
end