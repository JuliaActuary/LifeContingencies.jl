using LifeContingencies
using LifeContingencies: l, D, M, N, C
using Test
using FinanceCore
using MortalityTables

@testset "LifeContingencies" begin
    include("test_mortality.jl")
    include("simple_mort.jl")
    include("AMLCR.jl")
    include("joint_life.jl")
    include("single_life.jl")
    include("engine.jl")
    include("life_models.jl")
    include("ltc.jl")
    include("regression.jl")
    include("product_values.jl")
    include("policies.jl")
end
