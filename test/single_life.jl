@testset "Single Life" begin
    @testset "issue age 116" begin
        t = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]
        i = Yields.Constant(0.05)
        ins = LifeContingency(SingleLife(mort = t.ultimate, issue_age = 116), i)


        @test l(ins, 0) ≈ 1.0
        @test l(ins, 1) ≈ 0.200120000000000
        @test l(ins, 2) ≈ 0.030764447600000

        @test D(ins, 0) ≈ 1.0
        @test D(ins, 1) ≈ 0.190590476190476
        @test D(ins, 2) ≈ 0.027904260861678

        @test N(ins, 0) ≈ 1.221415195080500
        @test N(ins, 1) ≈ 0.221415195080502
        @test N(ins, 2) ≈ 0.030824718890026

        @test C(ins, 0) ≈ 0.761790476190476000
        @test C(ins, 1) ≈ 0.153610478367347000
        @test C(ins, 2) ≈ 0.023794627623916200

        @test M(ins, 0) ≈ 0.9418373716628330
        @test M(ins, 1) ≈ 0.1800468954723570
        @test M(ins, 2) ≈ 0.0264364171050101

        @test present_value(Insurance(ins)) ≈ 0.9418373716628330
        @test present_value(AnnuityDue(ins)) ≈ 1.2214151950805000
        
        qs = t.ultimate[116:118]
        @test present_value(Insurance(ins, 3)) ≈ sum(qs .* [1;cumprod(1 .- qs[1:2])] .* [1.05 ^ -t for t in 1:3])
        @test present_value(AnnuityDue(ins, n=3)) ≈ sum([1;cumprod(1 .- qs[1:2])] .* [1.05 ^ -t for t in 0:2])
        
        @test LifeContingencies.V(ins,1) == reserve_premium_net(ins,1)
        @test LifeContingencies.v(ins,1) == Yields.discount(ins,1)
        @test LifeContingencies.A(ins) == present_value(Insurance(ins))
        @test LifeContingencies.ä(ins) == present_value(AnnuityDue(ins))
        @test LifeContingencies.a(ins) == present_value(AnnuityImmediate(ins))
        @test LifeContingencies.P(ins) == premium_net(ins)
        @test LifeContingencies.ω(ins) == omega(ins)
    end

    @testset "issue age 30" begin
        t = tbls["2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB"]
        i = Yields.Constant(0.05)
        ins = LifeContingency(SingleLife(mort = t.select[30], issue_age = 30), i)


        @test l(ins, 0) ≈ 1.0
        @test l(ins, 1) ≈ 0.999670000000000
        @test l(ins, 2) ≈ 0.999210151800000


        @test D(ins, 0) ≈ 1.0
        @test D(ins, 1) ≈ 0.952066666666667
        @test D(ins, 2) ≈ 0.906313062857143


        @test N(ins, 0) ≈ 18.673525637928100
        @test N(ins, 1) ≈ 17.673525637928100
        @test N(ins, 2) ≈ 16.721458971261400

        @test C(ins, 0) ≈ 0.000314285714285764
        @test C(ins, 1) ≈ 0.000417095873015874
        @test C(ins, 2) ≈ 0.000474735413877510

        @test M(ins, 0) ≈ 0.1107844934319970
        @test M(ins, 1) ≈ 0.1104702077177110
        @test M(ins, 2) ≈ 0.1100531118446950

        @test present_value(Insurance(ins)) ≈ 0.1107844934319970
        @test present_value(AnnuityDue(ins)) ≈ 18.6735256379281000
        @test premium_net(ins) ≈ 0.0059327036350854
        @test reserve_premium_net(ins, 1) ≈ 0.0059012862412992
        @test reserve_premium_net(ins, 2) ≈ 0.0119711961204193

        qs = t.select[30][30:55]
        @test present_value(Insurance(ins, 26)) ≈ sum(qs .* [1;cumprod(1 .- qs[1:25])] .* [1.05 ^ -t for t in 1:26])
        @test present_value(AnnuityDue(ins, n=26)) ≈ sum([1;cumprod(1 .- qs[1:25])] .* [1.05 ^ -t for t in 0:25])

        @test premium_net(ins, 26) ≈ insurance(ins, 26) /  annuity_due(ins, 26) 

    end
end