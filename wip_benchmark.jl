using LifeContingencies
using MortalityTables
using Yields
import LifeContingencies: V, ä     # pull the shortform notation into scope
using BenchmarkTools

# load mortality rates from MortalityTables.jl
vbt2001 = MortalityTables.table("2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB")

issue_age = 30
life = SingleLife(                 # The life underlying the risk
    mort = vbt2001.select[issue_age],    # -- Mortality rates
)

yield = Yields.Constant(0.05)      # Using a flat 5% interest rate

lc = LifeContingency(life, yield)  # LifeContingency joins the risk with interest

@benchmark LifeContingencies.N(lc, 10)

ins = Insurance(lc)
premium_net(lc)
