using LifeContingencies
using LifeContingencies: l,D,M,N,C
using Test
using MortalityTables
const Yields = LifeContingencies.Yields

include("test_mortality.jl")
include("simple_mort.jl")
include("AMLCR.jl")
tbls = MortalityTables.tables()
include("joint_life.jl")
include("single_life.jl")