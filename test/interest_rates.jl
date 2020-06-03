@testset "interest rates" begin

    ## functional interest rate
    @testset "functional interest rate" begin
        i = InterestRate(time->0.05)

        @test v(i,0) == 1.0
        @test v(i,1) == 1 / 1.05
        @test v(i,2) == 1 / 1.05 ^ 2
        @test v(i,3) == 1 / 1.05 ^ 3
        @test v(i,1,2) == 1 / 1.05
        @test rate(i,1) == 0.05
        @test rate(i,2) == 0.05

        @test v.(i,1:3) == [1 / 1.05 ^ t for t in 1:3]

    end

    ## vector interest rate
    @testset "vector interest rate" begin
        i = InterestRate([0.05, 0.05, 0.05])

        @test v(i,0) == 1.0
        @test v(i,1) == 1 / 1.05
        @test v(i,2) == 1 / 1.05 ^ 2
        @test v(i,3) == 1 / 1.05 ^ 3
        @test v(i,1,2) == 1 / 1.05
        @test rate(i,1) == 0.05
        @test rate(i,2) == 0.05

        @test v.(i,1:3) == [1 / 1.05 ^ t for t in 1:3]
    end

    ## real interest rate
    @testset "constant interest rate" begin
        i = InterestRate(0.05)

        @test v(i,0) == 1.0
        @test v(i,1) == 1 / 1.05
        @test v(i,2) == 1 / 1.05 ^ 2
        @test v(i,3) == 1 / 1.05 ^ 3
        @test v(i,1,2) == 1 / 1.05
        @test rate(i,1) == 0.05
        @test rate(i,2) == 0.05
        
        @test v.(i,1:3) == [1 / 1.05 ^ t for t in 1:3]
    end

    ## Stochastic interest rate
    @testset "stochastic interest rate" begin
        i4 = InterestRate((x->rand(Normal(0.05, 0.01))))
        # auto-correlated interest rate
        i5 = InterestRate(
            time->time <= 1 ? 0.05 : rand(Normal(last(i5.rate_vector), 0.01)),
        )

        @test v(i4,0) == 1.0
        @test v(i5,0) == 1.0
        @test v(i4,1) > 0
        @test v(i5,1) > 0
        @test v(i4, 120, 1) > 0
        @test v(i5, 120, 1) > 0
    end
end
