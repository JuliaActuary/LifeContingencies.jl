@testset "Joint Life" begin


    @testset "Joint Last Survivor unknown status" begin

        @testset "ASM Manual 13th Ed., Example 54B" begin
            q1 = UltimateMortality([.10,.12,.14,.16,.18],start_age=80)
            q2 = UltimateMortality([.07,.09,.11,.13,.15],start_age=80)
            
            l1 = SingleLife(mortality=q1,issue_age=82)
            l2 = SingleLife(mortality=q2,issue_age=80)
            j = JointLife(lives=(l1,l2))
            
            @test survival(j,2) ≈ 0.95733 atol=1e-5
            @test survival(j,3) ≈ 0.899399 atol=1e-5
        end

        @testset "misc properties" begin
            q = UltimateMortality([.1 for t in 1:200])

            l1 = SingleLife(mortality=q)
            l2 = SingleLife(mortality=q)
            j = JointLife(lives=(l1,l2))
            
            ins0 = Insurance(j,Yields.Constant(0.0))
            survival(j,1,2)
            @test 1- survival(j,4)/survival(j,3) ≈ decrement(j,3,4)
            @test pv(ins0) ≈ 1.0 atol=1e-6 # at zero percent discount the benefit should sum to the unit
            @test last(collect(survival(ins0))) ≈ 0.0 atol=1e-6            

        end

        @testset "ALMCR §9.4" begin
            ℓ₁ = [43302, 42854, 42081, 41351, 40050]
            ℓ₂ = [47260, 47040, 46755, 46500, 46227]

            ps₁ = ℓ₁ ./ ℓ₁[1]
            qs₁ = [1 - ps₁[t] / ps₁[t-1] for t = 2:5]

            ps₂ = ℓ₂ ./ ℓ₂[1]
            qs₂ = [1 - ps₂[t] / ps₂[t-1] for t = 2:5]

            m1 = UltimateMortality(qs₁, start_age = 65)
            m2 = UltimateMortality(qs₂, start_age = 60)

            @test decrement(m1, 65, 66) == 1 - ℓ₁[2] / ℓ₁[1]
            @test decrement(m2, 60, 61) == 1 - ℓ₂[2] / ℓ₂[1]

            l1 = SingleLife(mortality = m1, issue_age = 65)
            l2 = SingleLife(mortality = m2, issue_age = 60)

            jl = JointLife(lives = (l1, l2), contingency = LastSurvivor(), joint_assumption = Frasier())

            @test isapprox(survival(jl, 2), 0.9997, atol = 1e-4)


            ins = LifeContingency(jl, Yields.Constant(0.05))
            ins_l1 = LifeContingency(jl.lives[1], Yields.Constant(0.05))
            ins_l2 = LifeContingency(jl.lives[2], Yields.Constant(0.05))
            # problem 9.1.f
            @test isapprox(present_value(AnnuityDue(ins, 5)), 4.5437, atol = 1e-4)

            @test isapprox(present_value(AnnuityDue(ins)), 4.5437, atol = 1e-4)
        end

        @testset "CIA tables" begin
            m1 = MortalityTables.table("1986-92 CIA – Male Smoker, ANB")
            m2 = MortalityTables.table("1986-92 CIA – Female Nonsmoker, ANB")
            l1 = SingleLife(mortality = m1.ultimate, issue_age = 40)
            l2 = SingleLife(mortality = m2.ultimate, issue_age = 37)

            jl = JointLife(lives = (l1, l2), contingency = LastSurvivor(), joint_assumption = Frasier())

            @testset "independent lives" begin
                for time = 1:40
                    tpx = survival(l1, time)
                    tpy = survival(l2, time)

                    @test survival(jl, time) == tpx + tpy - tpx * tpy
                end
            end

            q_annual = [0.00000141120, 0.00000478349, 0.00000921100, 0.00001508953, 0.00002255325, 0.00003179413, 0.00004327035, 0.00005782855, 0.00007524178, 0.00009695039, 0.00012370408, 0.00015606419, 0.00019612090, 0.00024529620, 0.00030502659, 0.00037768543, 0.00046587280, 0.00057325907, 0.00070238876, 0.00085952824, 0.00104786439, 0.00127420204, 0.00154640464, 0.00187374100, 0.00226186101, 0.00272457482, 0.00327193743, 0.00391984214, 0.00468084563, 0.00557778027, 0.00662135901, 0.00783684326, 0.00924475551, 0.01086696400, 0.01272977389, 0.01485150445, 0.01727277853, 0.02000566587, 0.02308982834, 0.02654184882, 0.03039819991, 0.03469299691, 0.03944737905, 0.04469931521, 0.05048294677, 0.05683522818, 0.06379854263, 0.07142629169, 0.07976664920, 0.08888579420, 0.09884411368, 0.10971505011, 0.12159455247, 0.13456410066, 0.14873755448, 0.16421406941, 0.18111392905, 0.19954137714, 0.21962070363, 0.24144744481, 0.26515968560, 0.29099967654, 0.31901974549, 0.35111309929, 0.39733960046, 0.47004540325, 0.58255000000, 0.74852030000, 1.00000000000]
            q_cumulative = [0.00000141120, 0.00000619469, 0.00001540563, 0.00003049492, 0.00005304748, 0.00008483992, 0.00012810660, 0.00018592774, 0.00026115553, 0.00035808060, 0.00048174038, 0.00063772939, 0.00083372522, 0.00107881691, 0.00138351443, 0.00176067732, 0.00222572986, 0.00279771301, 0.00349813669, 0.00435465818, 0.00539795948, 0.00666528343, 0.00820138084, 0.01005975458, 0.01229886182, 0.01498992747, 0.01821281880, 0.02206126957, 0.02663884979, 0.03206804441, 0.03847706939, 0.04601237389, 0.05483175625, 0.06510286552, 0.07700389465, 0.09071177542, 0.10641770955, 0.12429441828, 0.14451430984, 0.16722048170, 0.19253547997, 0.22054884408, 0.25129614928, 0.28476269870, 0.32086998531, 0.35946849466, 0.40033347120, 0.44316542761, 0.48758225561, 0.53312891378, 0.57927637250, 0.62543608637, 0.67098101782, 0.71525516126, 0.75760741222, 0.79741168545, 0.83410325108, 0.86720651682, 0.89637071504, 0.92139174110, 0.94223548231, 0.95904493828, 0.97211041164, 0.98190281145, 0.98909354112, 0.99422007198, 0.99758716905, 0.99939322200, 1.00000000000]
            @testset "precalced vectors" begin
                for time = 1:40
                    @test isapprox(decrement(jl, time), q_cumulative[time], atol = 1e-6)
                end

                for time = 1:40
                    q′ = 1 - survival(jl, time) / survival(jl, time - 1)

                    @test isapprox(q′, q_annual[time], atol = 1e-6)
                end

                for time = 1:40
                    @test isapprox(survival(jl, time), 1 - q_cumulative[time], atol = 1e-6)
                end
            end
        end



    end
end