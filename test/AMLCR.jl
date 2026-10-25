# tests based on AMLCR 2nd ed,
@testset "AMLCR Math" begin

    # §5.7 payment frequency and certain (Tables 5.1 and 5.2)
    # AMLCR_std stops at age 120 with rates short of 1, so the life annuities are written as
    # annuities to the end of the rates; the difference is far inside the tolerance
    function f(age)
        life = SingleLife(mortality=AMLCR_std, issue_age=age)
        n = omega(life)
        int = 0.05
        lc = [
            AnnuityImmediate(life, int, n)
            AnnuityImmediate(life, int, n, frequency=4)
            AnnuityDue(life, int, n)
            AnnuityDue(life, int, n, frequency=4)
            AnnuityImmediate(life, int, 10)
            AnnuityImmediate(life, int, 10, frequency=4)
            AnnuityDue(life, int, 10, frequency=4)
        ]

        return present_value.(lc)
    end

    # atol only to two decimals b/c AMLCR uses rounded rates?
    @test all(isapprox.(f(20), [18.966, 19.338, 19.966, 19.588, 7.711, 7.855, 7.952], atol=0.01))
    @test all(isapprox.(f(80), [7.548, 7.917, 8.548, 8.167, 6.128, 6.373, 6.539], atol=0.01))

    life = SingleLife(mortality=AMLCR_std, issue_age=20)
    n = omega(life)
    int = 0.05

    # property tests

    @test present_value(AnnuityDue(life, int, n)) > present_value(AnnuityDue(life, int, n - 5, start_time=5))

    @test present_value(AnnuityDue(life, int, 5, certain=5, start_time=5)) ≈ sum([1 for t = 5:9] .* [1 / 1.05^t for t = 5:9])

    # relation on pg 124
    @test issorted(present_value.([
        AnnuityImmediate(life, int, n)
        AnnuityImmediate(life, int, n, frequency=4)
        AnnuityDue(life, int, n, frequency=4)
        AnnuityDue(life, int, n)
    ]))

end
