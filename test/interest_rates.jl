@testset "basic interest rates" begin


    ## vector interest rate
    @testset "vector interest rate" begin
        i = InterestRate([0.05, 0.05, 0.05])

        @test disc(i,0) == 1.0
        @test disc(i,1) == 1 / 1.05
        @test disc(i,2) == 1 / 1.05 ^ 2
        @test disc(i,3) == 1 / 1.05 ^ 3
        @test disc(i,1,2) == 1 / 1.05
        @test rate(i,1) == 0.05
        @test rate(i,2) == 0.05

        @test disc.(i,1:3) == [1 / 1.05 ^ t for t in 1:3]
    end

    ## real interest rate
    @testset "constant interest rate" begin
        i = InterestRate(0.05)

        @test disc(i,0) == 1.0
        @test disc(i,1) == 1 / 1.05
        @test disc(i,2) == 1 / 1.05 ^ 2
        @test disc(i,3) == 1 / 1.05 ^ 3
        @test disc(i,1,2) == 1 / 1.05
        @test rate(i,1) == 0.05
        @test rate(i,2) == 0.05
        
        @test disc.(i,1:3) == [1 / 1.05 ^ t for t in 1:3]
    end
end

@testset "DiscountFactor Iterator" begin

    target = [1 / 1.05 ^ t for t in 0:4 ]

    @testset "contsant" begin
        df = DiscountFactor(InterestRate(0.05),1)
        
        ds = Iterators.take(df,5) |> collect

        @test all(ds .≈ target)

        @test length(Iterators.take(df,100)) == 100

        # can't collect an infinite series
        @test_throws MethodError collect(df)

        @test df == InterestRate(0.05)(1)
    end

    @testset "vector" begin
    df = DiscountFactor(InterestRate(repeat([0.05],4)),1)

        ds = Iterators.take(df,5) |> collect
        @test all(ds .≈ target)
        @test all(collect(df) .≈ target)
        @test length(df) == 5

        @test_broken InterestRate([0.05,0.05,0.05,0.05])(1) == df #https://stackoverflow.com/questions/62336686/struct-equality-with-arrays
    end

end

@testset "passthrough life contingency" begin
    ins = LifeContingency(
        SingleLife(
            mort = UltimateMortality([0.5]),
            issue_age = 0
        ),
        InterestRate(0.05)
    )

    @test disc(ins,1) ≈ 1/1.05
    @test disc(ins,1,2) ≈ 1/1.05
end