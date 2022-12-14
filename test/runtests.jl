using LifeContingencies
using LifeContingencies: l,D,M,N,C
using Test
using MortalityTables
using ActuaryUtilities
const Yields = LifeContingencies.Yields

include("test_mortality.jl")
include("simple_mort.jl")
include("AMLCR.jl")
include("joint_life.jl")
include("single_life.jl")