using LifeContingencies
using LifeContingencies: l,D,M,N,C
using Test
using MortalityTables
const Yields = LifeContingencies.Yields

include("test_mortality.jl")
include("AMLCR.jl")
include("simple_mort.jl")
tbls = MortalityTables.tables()
include("joint_life.jl")
include("single_life.jl")