@testset "Joint Life" begin

        
    @testset "Joint Last Survivor unknown status" begin
        
        @testset "ALMCR §9.4" begin
            ℓ₁ =[43302,42854,42081,41351,40050]
            ℓ₂ =[47260,47040,46755,46500,46227]

            ps₁ =  ℓ₁ ./ ℓ₁[1]
            qs₁ = 1.0 .- ps₁

            ps₂ =  ℓ₂ ./ ℓ₂[1]
            qs₂ = 1.0 .- ps₂
            
            m1 = UltimateMortality(qs₁,65)
            m2 = UltimateMortality(qs₂,60)

            @test q(m1,60,1,1) == 1 - ℓ₁[2] / ℓ₁[1]

            l1 = SingleLife(mort = m1.ultimate, issue_age = 40)
            l2 = SingleLife(mort = m2.ultimate, issue_age = 37)

            jl = JointLife(l1, l2, LastSurvivor(),Frasier())

            @test isapprox(p(jl,3), 0.9195,atol=1e-4)


        end
    
        @testset "CIA tables" begin
            m1 = tbls["1986-92 CIA – Male Smoker, ANB"]
            m2 = tbls["1986-92 CIA – Female Smoker, ANB"]
            l1 = SingleLife(mort = m1.ultimate, issue_age = 40)
            l2 = SingleLife(mort = m2.ultimate, issue_age = 37)

            jl = JointLife(l1, l2, LastSurvivor(),Frasier())
            q_target = [0.00018170014800003,0.00087047571103977,0.00209600326444471,0.00406733590338308,0.00701032205354360,0.01114774282342570,0.01696123520352470,0.02519249631639440,0.03603315178691460,0.05063301389010460,0.07021672521431740,0.09569328881039310,0.12954190211015600,0.17387259989868400,0.23071598805958500,0.30501021782228800,0.38727069239372700,0.48831953331608000,0.61089788425138900,0.76106395724387700,0.94229790241332700,1.16135852283376000,1.42612748396757000,1.74592634393723000,2.12676449530076000,2.58236619163331000,3.12303759062790000,3.76472528213145000,4.52025167551057000,5.41243167352820000,6.45239363543940000,7.66540862005412000,9.07219386687465000,10.69477417411460000,12.55953571822740000,14.68497155253610000,17.11156585212870000,19.85157152208010000,22.94447220585850000,26.40686796774260000]
                
            for duration in 1:40
                @show duration
                @test q(jl, duration) == q_target[duration]
            end
        end



    end
end