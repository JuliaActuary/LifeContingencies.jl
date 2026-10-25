struct UnsupportedDependence <: LifeContingencies.JointAssumption end

active_mass(contingency, occupancy) =
    sum((p for (statuses, p) in occupancy if LifeContingencies.active(contingency, statuses)); init=0.0)

@testset "lives as engine models" begin
    @testset "occupancy agrees with scalar survival" begin
        for fractional in (UniformDeaths(), ConstantForce(), MortalityTables.Balducci())
            single = SingleLife(UltimateMortality([0.1, 0.2, 0.3, 0.4, 1.0]); fractional_assump=fractional)
            other = SingleLife(UltimateMortality([0.05, 0.1, 0.2, 1.0]); fractional_assump=fractional)
            grid = 0:0.25:4
            p = project((;), single; grid, initial=LifeContingencies.initial_distribution(single), history=true)
            for (k, t) in enumerate(grid)
                @test get(p.history[k], :alive, 0.0) ≈ survival(single, t) atol = 1e-14
            end
            for contingency in (LastSurvivor(), FirstToDie())
                joint = JointLife(lives=(single, other); contingency)
                p = project((;), joint; grid, initial=LifeContingencies.initial_distribution(joint), history=true)
                for (k, t) in enumerate(grid)
                    @test active_mass(contingency, p.history[k]) ≈ survival(joint, t) atol = 1e-14
                end
            end
        end
    end

    @testset "status at issue" begin
        dead = SingleLife(UltimateMortality([0.5, 0.5]); alive=false)
        @test LifeContingencies.initial_distribution(dead) == [:dead => 1.0]
        p = project((;), dead; grid=0:5, initial=LifeContingencies.initial_distribution(dead))
        @test p.final == Dict(:dead => 1.0)
        # the dead need no mortality rates, but the living do
        @test collect(transitions(dead, Interval(5, 6), :dead)) == [:alive => 0.0, :dead => 1.0]
        @test_throws DomainError transitions(dead, Interval(5, 6), :alive)
        joint = JointLife(lives=(dead, SingleLife(UltimateMortality([0.5, 1.0]))))
        @test LifeContingencies.initial_distribution(joint) == [(:dead, :alive) => 1.0]
    end

    @testset "conditioning cases" begin
        single = SingleLife(UltimateMortality([0.5, 0.5, 0.5, 1.0]))
        joint = JointLife(lives=(single, single))
        next_year(initial) = active_mass(LastSurvivor(), project((;), joint; grid=1:2, initial).final)
        @test next_year([(:alive, :alive) => 1.0]) ≈ 3 / 4
        @test next_year([(:alive, :dead) => 1.0]) ≈ 1 / 2
        at_one = project((;), joint; grid=0:1, initial=LifeContingencies.initial_distribution(joint)).final
        aggregate = condition(at_one, statuses -> LifeContingencies.active(LastSurvivor(), statuses))
        @test next_year(aggregate) ≈ 7 / 12
        @test next_year(aggregate) ≈ survival(joint, 1, 2)
    end

    @testset "inclusion–exclusion from a correlated start" begin
        single = SingleLife(UltimateMortality([0.3, 0.4, 0.5, 1.0]))
        joint = JointLife(lives=(single, single))
        at_one = project((;), joint; grid=0:1, initial=LifeContingencies.initial_distribution(joint)).final
        # conditioning on at least one alive makes the two statuses dependent
        correlated = condition(at_one, statuses -> LifeContingencies.active(LastSurvivor(), statuses))
        for occupancy in project((;), joint; grid=1:4, initial=correlated, history=true).history
            alive(i) = sum((p for (statuses, p) in occupancy if statuses[i] === :alive); init=0.0)
            @test active_mass(FirstToDie(), occupancy) + active_mass(LastSurvivor(), occupancy) ≈ alive(1) + alive(2)
        end
    end

    @testset "policy values agree with the textbook products" begin
        vbt = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")
        life = SingleLife(vbt.select[30], issue_age=30)
        contract = (
            annuity=StatePayment((t, s) -> s === :alive ? 1.0 : 0.0),
            death=TransitionPayment((interval, from, to) -> from === :alive && to === :dead ? 1.0 : 0.0),
        )
        valued = policy_values(contract, life, 0.05; grid=0:omega(life), terminal=0)
        @test valued.before[:alive].annuity ≈ present_value(AnnuityDue(life, 0.05))
        @test valued.before[:alive].death ≈ present_value(Insurance(life, 0.05))
        @test valued.before[:dead] == (annuity=0.0, death=0.0)
    end

    @testset "unsupported joint assumptions" begin
        single = SingleLife(UltimateMortality([0.5, 1.0]))
        joint = JointLife(lives=(single, single), joint_assumption=UnsupportedDependence())
        @test_throws ArgumentError transitions(joint, Interval(0, 1), (:alive, :alive))
    end
end
