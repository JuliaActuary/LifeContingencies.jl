@testset "basic interest rates" begin

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
            time->time <= 1 ? 0.05 : rand(Normal(last(i5.rate), 0.01)),
        )

        @test v(i4,0) == 1.0
        @test v(i5,0) == 1.0
        @test v(i4,1) > 0
        @test v(i5,1) > 0
        @test v(i4, 120, 1) > 0
        @test v(i5, 120, 1) > 0
    end
end

@testset "DiscountFactor" begin

    target = [1 / 1.05 ^ t for t in 0:4 ]

    @testset "consant" begin
        df = DiscountFactor(InterestRate(0.05))

        ds = Iterators.take(df,5) |> collect

        @test all(ds .≈ target)

        @test length(Iterators.take(df,100)) == 100

        # can't collect an infinite series
        @test_throws MethodError collect(df)

    end

    @testset "vector" begin
    df = DiscountFactor(InterestRate(repeat([0.05],4)))

        ds = Iterators.take(df,5) |> collect
        @test all(ds .≈ target)

        @test all(collect(df) .≈ target)
        @test length(df) == 5


    end

    @testset "nonterminating functional" begin
        df = DiscountFactor(InterestRate(time-> 0.05))
        ds = Iterators.take(df,5) |> collect

        @test all(ds .≈ target)

        @test length(Iterators.take(df,100) |> collect) == 100

        # can't collect an infinite series
        @test_throws MethodError collect(df)
    end

    @testset "terminating functional" begin

        df = DiscountFactor(InterestRate(time-> time < 3 ? 0.05 : nothing))
        @test all(Iterators.take(df,3) |> collect .≈   [1.0, 1 / 1.05, 1/1.05^2])
    end

end