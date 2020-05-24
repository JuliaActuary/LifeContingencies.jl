using LifeContingencies
using Test
import Distributions: Normal
using MortalityTables

include("interest_rates.jl")
include("simple_mort.jl")
tbls = MortalityTables.tables()
include("single_life.jl")
include("joint_life.jl")