using LifeContingencies
using LifeContingencies: l, D, M, N, C
using Test
using FinanceCore
using MortalityTables

FinanceCore.present_value(0.05, 10)
include("test_mortality.jl")
include("simple_mort.jl")
include("AMLCR.jl")
include("joint_life.jl")
include("single_life.jl")