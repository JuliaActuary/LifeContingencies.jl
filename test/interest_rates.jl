@testset "interest rates" begin

    ## functional interest rate
    @testset "functional interest rate" begin
        i1 = InterestRate(time->0.05)

        @test 1 / (1.05) == v(i1)
        @test 1 / (1.05) == v(i1, 1)
        @test 1 / (1.05^2) == v(i1, 2, 1)
        @test 0.05 == rate(i1, 1)
    end

    ## vector interest rate
    @testset "vector interest rate" begin
        i2 = InterestRate([0.05, 0.05, 0.05])
        @test 1 / (1.05) == v(i2)
        @test 1 / (1.05) == v(i2, 1)
        @test 1 / (1.05^2) == v(i2, 2, 1)
    end

    ## real interest rate
    @testset "constant interest rate" begin
        i3 = InterestRate(0.05)

        @test 1 / (1.05) == v(i3)
        @test 1 / (1.05) == v(i3, 1)
        @test 1 / (1.05^2) == v(i3, 2, 1)
        @test 1 / (1.05^120) ≈ v(i3, 120, 1)
    end

    ## Stochastic interest rate
    @testset "stochastic interest rate" begin
        i4 = InterestRate((x->rand(Normal(0.05, 0.01))))
        # auto-correlated interest rate
        i5 = InterestRate(
            time->time <= 1 ? 0.05 : rand(Normal(last(i5.rate_vector), 0.01)),
        )

        @test v(i4) > 0
        @test v(i5) > 0
        @test v(i4, 120, 1) > 0
        @test v(i5, 120, 1) > 0
    end
end
