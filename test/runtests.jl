using LifeContingencies
using LifeContingencies: l,D,M,N,C
using Test
using MortalityTables

include("interest_rates.jl")
include("simple_mort.jl")
tbls = MortalityTables.tables()
include("joint_life.jl")
include("single_life.jl")