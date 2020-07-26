using LifeContingencies
using LifeContingencies: l,D,M,N,C
using Test
import Distributions: Normal
using MortalityTables

include("interest_rates.jl")
include("simple_mort.jl")
tbls = MortalityTables.tables()
include("joint_life.jl")
include("single_life.jl")