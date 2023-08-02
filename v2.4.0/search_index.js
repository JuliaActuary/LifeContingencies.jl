var documenterSearchIndex = {"docs":
[{"location":"api/#API-Reference","page":"API Reference","title":"API Reference","text":"","category":"section"},{"location":"api/","page":"API Reference","title":"API Reference","text":"","category":"page"},{"location":"api/","page":"API Reference","title":"API Reference","text":"","category":"page"},{"location":"api/","page":"API Reference","title":"API Reference","text":"Modules = [LifeContingencies]\n","category":"page"},{"location":"api/#LifeContingencies.Contingency","page":"API Reference","title":"LifeContingencies.Contingency","text":"Contingency()\n\nAn abstract type representing the different triggers for contingent benefits. Available options to use include:\n\nLastSurvivor()\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.Frasier","page":"API Reference","title":"LifeContingencies.Frasier","text":"Frasier()\n\nThe assumption of independent lives in a joint life calculation. Is a subtype of JointAssumption.\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.Insurance-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.Insurance","text":"Insurance(lc::LifeContingency, term)\nInsurance(life,interest, term)\nInsurance(lc::LifeContingency)\nInsurance(life,interest)\n\nLife insurance with a term period of term. If term is nothing, then whole life insurance.\n\nIssue age is based on the issue_age in the LifeContingency lc.\n\nExamples\n\nins = Insurance(\n    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),\n    FinanceModels.Yield.Constant(0.05),\n    1           # 1 year term\n) \n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.JointAssumption","page":"API Reference","title":"LifeContingencies.JointAssumption","text":"JointAssumption()\n\nAn abstract type representing the different assumed relationship between the survival of the lives on a JointLife. Available options to use include:\n\nFrasier()\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.JointLife","page":"API Reference","title":"LifeContingencies.JointLife","text":"struct JointLife\n    lives\n    contingency\n    joint_assumption\nend\n\nA `Life` object containing the necessary assumptions for contingent maths related to a joint life insurance. Use with a `LifeContingency` to do many actuarial present value calculations.\n\nKeyword arguments:\n\nlives is a tuple of two SingleLifes\ncontingency default is LastSurvivor(). It is the trigger for contingent benefits. See ?Contingency. \njoint_assumption Default value is Frasier(). It is the assumed relationship between the mortality of the two lives. See ?JointAssumption. \n\nExamples\n\nusing MortalityTables\nmortality = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\nl1 = SingleLife(\n    mortality       = mortality.select[30], \n    issue_age  = 30          \n)\nl2 = SingleLife(\n    mortality       = mortality.select[30], \n    issue_age  = 30          \n)\n\njl = JointLife(\n    lives = (l1,l2),\n    contingency = LastSurvivor(),\n    joint_assumption = Frasier()\n)\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.LastSurvivor","page":"API Reference","title":"LifeContingencies.LastSurvivor","text":"LastSurvivor()\n\nThe contingency whereupon benefits are payable upon both lives passing. Is a subtype of Contingency\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.LifeContingency","page":"API Reference","title":"LifeContingencies.LifeContingency","text":"struct LifeContingency\n    life::Life\n\n\n\n\n\n","category":"type"},{"location":"api/#LifeContingencies.SingleLife","page":"API Reference","title":"LifeContingencies.SingleLife","text":"struct SingleLife\n    mortality\n    issue_age::Int\n    alive::Bool\n    fractional_assump::MortalityTables.DeathDistribution\nend\n\nA Life object containing the necessary assumptions for contingent maths related to a single life. Use with a LifeContingency to do many actuarial present value calculations. \n\nKeyword arguments:\n\nmortality pass a mortality vector, which is an array of applicable mortality rates indexed by attained age\nissue_age is the assumed issue age for the SingleLife and is the basis of many contingency calculations.\nalive Default value is true. Useful for joint insurances with different status on the lives insured.\nfractional_assump. Default value is Uniform(). This is a DeathDistribution from the MortalityTables.jl package and is the assumption to use for non-integer ages/times.\n\nExamples\n\nusing MortalityTables\nmortality = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\nSingleLife(\n    mort       = mort.select[30], \n    issue_age  = 30          \n)\n\n\n\n\n\n","category":"type"},{"location":"api/#FinanceCore.discount-Tuple{I} where I<:Insurance","page":"API Reference","title":"FinanceCore.discount","text":"discount(Insurance)\n\nThe discount vector for the given insurance.\n\nTo get the fully computed and allocated vector, call collect(discount(...)).\n\n\n\n\n\n","category":"method"},{"location":"api/#FinanceCore.present_value-Tuple{T} where T<:Insurance","page":"API Reference","title":"FinanceCore.present_value","text":"present_value(Insurance)\n\nThe actuarial present value of the given insurance benefits.\n\n\n\n\n\n","category":"method"},{"location":"api/#FinanceCore.present_value-Union{Tuple{T}, Tuple{T, Any}} where T<:Insurance","page":"API Reference","title":"FinanceCore.present_value","text":"present_value(Insurance,`time`)\n\nThe actuarial present value of the given insurance benefits, as if you were standing at time. \n\nFor example, if the given Insurance has decremented payments [1,2,3,4,5] at times [1,2,3,4,5] and you call pv(ins,3),  you will get the present value of the payments [4,5] at times [1,2].\n\nTo get an undecremented present value, divide by the survivorship to that timepoint:\n\npresent_value(ins,10) / survival(ins,10)\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.APV-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.APV","text":"APV(lc::LifeContingency,to_time)\n\nThe actuarial present value which is the survival times the discount factor for the life contingency.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.AnnuityDue-Tuple{Any, Any, Any}","page":"API Reference","title":"LifeContingencies.AnnuityDue","text":"AnnuityDue(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)\nAnnuityDue(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)\n\nAnnuity due with the benefit period starting at start_time and ending after n periods with frequency payments per year of 1/frequency amount and a certain period with non-contingent payments. \n\nExamples\n\nins = AnnuityDue(\n    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),\n    FinanceModels.Yield.Constant(0.05),\n    1, # term of policy\n) \n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.AnnuityImmediate-Tuple{Any, Any, Any}","page":"API Reference","title":"LifeContingencies.AnnuityImmediate","text":"AnnuityImmediate(lc::LifeContingency; term=nothing, start_time=0; certain=nothing,frequency=1)\nAnnuityImmediate(life, interest; term=nothing, start_time=0; certain=nothing,frequency=1)\n\nAnnuity immediate with the benefit period starting at start_time and ending after term periods with frequency payments per year of 1/frequency amount and a certain period with non-contingent payments. \n\nExamples\n\nins = AnnuityImmediate(\n    SingleLife(mortality = UltimateMortality([0.5,0.5]),issue_age = 0),\n    FinanceModels.Yield.Constant(0.05),\n    1 # term of policy\n) \n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.C-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.C","text":"C(lc::LifeContingency, to_time)\n\nC_x is a retrospective actuarial commutation function which is the product of the discount factor and the difference in l (l_x).\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.D-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.D","text":"D(lc::LifeContingency, to_time)\n\nD_x is a retrospective actuarial commutation function which is the product of the survival and discount factor.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.M-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.M","text":"M(lc::LifeContingency, from_time)\n\nThe M_x actuarial commutation function where the from_time argument is x. Issue age is based on the issue_age in the LifeContingency lc.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.N-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.N","text":"N(lc::LifeContingency, from_time)\n\nN_x is a prospective actuarial commutation function which is the sum of the D (D_x) values from the given time to the end of the mortality table.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.benefit-Tuple{I} where I<:Insurance","page":"API Reference","title":"LifeContingencies.benefit","text":"benefit(Insurance)\n\nThe unit benefit for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.cashflows-Tuple{I} where I<:Insurance","page":"API Reference","title":"LifeContingencies.cashflows","text":"cashflows(Insurance)\n\nThe vector of decremented benefit cashflows for the given insurance. \n\nTo get the fully computed and allocated vector, call collect(cashflows(...)).\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.l-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.l","text":"l(lc::LifeContingency, to_time)\n\nl_x is a retrospective actuarial commutation function which is the survival up to a certain point in time. By default, will have a unitary basis (ie 1.0), but you can specify basis keyword argument to use something different (e.g. 1000 is common in the literature.)\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.premium_net-Tuple{LifeContingency}","page":"API Reference","title":"LifeContingencies.premium_net","text":"premium_net(lc::LifeContingency)\npremium_net(lc::LifeContingency,to_time)\n\nThe net premium for a whole life insurance (without second argument) or a term life insurance through to_time.\n\nThe net premium is based on 1 unit of insurance with the death benfit payable at the end of the year and assuming annual net premiums.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.probability-Tuple{I} where I<:Insurance","page":"API Reference","title":"LifeContingencies.probability","text":"probability(Insurance)\n\nThe vector of contingent benefit probabilities for the given insurance.\n\nTo get the fully computed and allocated vector, call collect(probability(...)).\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.reserve_premium_net-Tuple{LifeContingency, Any}","page":"API Reference","title":"LifeContingencies.reserve_premium_net","text":" reserve_premium_net(lc::LifeContingency,time)\n\nThe net premium reserve at the end of year time.\n\n\n\n\n\n","category":"method"},{"location":"api/#LifeContingencies.timepoints-Tuple{Insurance}","page":"API Reference","title":"LifeContingencies.timepoints","text":"timepoints(Insurance)\n\nThe vector of times corresponding to the cashflow vector for the given insurance.\n\nTo get the fully computed and allocated vector, call collect(timepoints(...)).\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.decrement-Tuple{LifeContingency, Any, Any}","page":"API Reference","title":"MortalityTables.decrement","text":"decrement(lc::LifeContingency,to_time)\ndecrement(lc::LifeContingency,from_time,to_time)\n\nReturn the probability of death for the given LifeContingency, with decrements beginning at time zero. \n\nExamples\n\njulia> q = [.1,.2,.3,.4];\n\njulia> l = SingleLife(mortality=q);\n\njulia> survival(l,1)\n0.9\n\njulia> decrement(l,1)\n0.09999999999999998\n\njulia> survival(l,1,2)\n0.8\n\njulia> decrement(l,1,2)\n0.19999999999999996\n\njulia> survival(l,1,3)\n0.5599999999999999\n\njulia> decrement(l,1,3)\n0.44000000000000006\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.omega-Tuple{LifeContingency}","page":"API Reference","title":"MortalityTables.omega","text":"omega(lc::LifeContingency)\nomega(l::Life)\nomega(i::InterestRate)\n\nLifes and LifeContingencys\n\nReturns the last defined timeperiod for both the interest rate and mortality table. Note that this is different than calling omega on a MortalityTable, which will give you the last `attainedage`.\n\nExample: if the LifeContingency has issue age 60, and the last defined attained age for the MortalityTable is 100, then omega of the MortalityTable will be 100 and omega of the  LifeContingency will be 40.\n\nInterestRates\n\nThe last period that the interest rate is defined for. Assumed to be infinite (Inf) for      functional and constant interest rate types. Returns the lastindex of the vector if      a vector type.\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.survival-Tuple{I} where I<:Insurance","page":"API Reference","title":"MortalityTables.survival","text":"survival(Insurance)\n\nThe survivorship vector for the given insurance.\n\nTo get the fully computed and allocated vector, call collect(survival(...)).\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.survival-Tuple{LifeContingency, Any}","page":"API Reference","title":"MortalityTables.survival","text":"survival(lc::LifeContingency,from_time,to_time)\nsurvival(lc::LifeContingency,to_time)\n\nReturn the probability of survival for the given LifeContingency, with decrements beginning at time zero. \n\nExamples\n\n```julia-repl julia> q = [.1,.2,.3,.4];\n\njulia> l = SingleLife(mortality=q);\n\njulia> survival(l,1) 0.9\n\njulia> decrement(l,1) 0.09999999999999998\n\njulia> survival(l,1,2) 0.8\n\njulia> decrement(l,1,2) 0.19999999999999996\n\njulia> survival(l,1,3) 0.5599999999999999\n\njulia> decrement(l,1,3) 0.44000000000000006\n\n```\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.survival-Tuple{L} where L<:LifeContingencies.Life","page":"API Reference","title":"MortalityTables.survival","text":"survival(life)\n\nReturn a survival vector for the given life.\n\n\n\n\n\n","category":"method"},{"location":"api/#MortalityTables.survival-Union{Tuple{I}, Tuple{I, Any}} where I<:Insurance","page":"API Reference","title":"MortalityTables.survival","text":"survival(Insurance,time)\n\nThe survivorship for the given insurance from time zero to time.\n\n\n\n\n\n","category":"method"},{"location":"api/","page":"API Reference","title":"API Reference","text":"<script>\n    window.goatcounter = {\n        path: function(p) { return location.host + p }\n    }\n</script>\n<script data-goatcounter=\"https://juliaactuary.goatcounter.com/count\"\n        async src=\"//gc.zgo.at/count.js\"></script>","category":"page"},{"location":"#LifeContingencies.jl","page":"Home","title":"LifeContingencies.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"(Image: Stable)  (Image: Dev) (Image: ) (Image: codecov)","category":"page"},{"location":"","page":"Home","title":"Home","text":"LifeContingencies is a package enabling actuarial life contingent calculations.","category":"page"},{"location":"#Features","page":"Home","title":"Features","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Integration with other JuliaActuary packages such as MortalityTables.jl\nFast calculations, with some parts utilizing parallel processing power automatically\nUse functions that look more like the math you are used to (e.g. A, ä) with Unicode support\nAll of the power, speed, convenience, tooling, and ecosystem of Julia\nFlexible and modular modeling approach","category":"page"},{"location":"#Package-Overview","page":"Home","title":"Package Overview","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Leverages MortalityTables.jl for","category":"page"},{"location":"","page":"Home","title":"Home","text":"the mortality calculations","category":"page"},{"location":"","page":"Home","title":"Home","text":"Contains common insurance calculations such as:\nInsurance(life,yield): Whole life\nInsurance(life,yield,n): Term life for n years\nä(life,yield): present_value of life-contingent annuity\nä(life,yield,n): present_value of life-contingent annuity due for n years\nContains various commutation functions such as D(x),M(x),C(x), etc.\nSingleLife and JointLife capable\nInterest rate mechanics via Yields.jl\nMore documentation available by clicking the DOCS badges at the top of this README","category":"page"},{"location":"#Examples","page":"Home","title":"Examples","text":"","category":"section"},{"location":"#Basic-Functions","page":"Home","title":"Basic Functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Calculate various items for a 30-year-old male nonsmoker using 2015 VBT base table and a 5% interest rate","category":"page"},{"location":"","page":"Home","title":"Home","text":"\nusing LifeContingencies\nusing MortalityTables\nusing Yields\nimport LifeContingencies: V, ä     # pull the shortform notation into scope\n\n# load mortality rates from MortalityTables.jl\nvbt2001 = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\nissue_age = 30\nlife = SingleLife(                 # The life underlying the risk\n    mort = vbt2001.select[issue_age],    # -- Mortality rates\n)\n\nyield = Yields.Constant(0.05)      # Using a flat 5% interest rate\n\nlc = LifeContingency(life, yield)  # LifeContingency joins the risk with interest\n\n\nins = Insurance(lc)                # Whole Life insurance\nins = Insurance(life, yield)       # alternate way to construct","category":"page"},{"location":"","page":"Home","title":"Home","text":"With the above life contingent data, we can calculate vectors of relevant information:","category":"page"},{"location":"","page":"Home","title":"Home","text":"cashflows(ins)                     # A vector of the unit cashflows\ntimepoints(ins)                    # The timepoints associated with the cashflows\nsurvival(ins)                      # The survival vector\nsurvival(ins,time)                 # The survivorship through `time`\nbenefit(ins)                       # The unit benefit vector\nprobability(ins)                   # The probability of benefit payment\npresent_value(ins)                 # the present value of the insurance benefits from time zero\npresent_value(ins,time)            # the present value of the insurance benefits from `time`","category":"page"},{"location":"","page":"Home","title":"Home","text":"Some of the above will return lazy results. For example, cashflows(ins) will return a Generator which can be efficiently used in most places you'd use a vector of cashflows (e.g. pv(...) or sum(...)) but has the advantage of being non-allocating (less memory used, faster computations). To get a computed vector instead of the generator, simply call collect(...) on the result: collect(cashflows(ins)).","category":"page"},{"location":"","page":"Home","title":"Home","text":"Or calculate summary scalars:","category":"page"},{"location":"","page":"Home","title":"Home","text":"present_value(ins)                 # The actuarial present value\npremium_net(lc)                    # Net whole life premium \nV(lc,5)                            # Net premium reserve for whole life insurance at time 5","category":"page"},{"location":"","page":"Home","title":"Home","text":"Other types of life contingent benefits:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Insurance(lc,10)                 # 10 year term insurance\nAnnuityImmediate(lc)               # Whole life annuity due\nAnnuityDue(lc)                     # Whole life annuity due\nä(lc)                              # Shortform notation\nä(lc, 5)                           # 5 year annuity due\nä(lc, 5, certain=5,frequency=4)    # 5 year annuity due, with 5 year certain payable 4x per year\n...                                # and more!","category":"page"},{"location":"#Constructing-Lives","page":"Home","title":"Constructing Lives","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"SingleLife(vbt2001.select[50])                 # no keywords, just a mortality vector\nSingleLife(vbt2001.select[50],issue_age = 60)  # select at 50, but now 60\nSingleLife(vbt2001.select,issue_age = 50)      # use issue_age to pick the right select vector\nSingleLife(mortality=vbt2001.select,issue_age = 50) # mort can also be a keyword\n","category":"page"},{"location":"#Net-Premium-for-Term-Policy-with-Stochastic-rates","page":"Home","title":"Net Premium for Term Policy with Stochastic rates","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Use a stochastic interest rate calculation to price a term policy:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using LifeContingencies, MortalityTables\nusing Distributions\n\nvbt2001 = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\n# use an interest rate that's normally distirbuted\nμ = 0.05\nσ = 0.01\n\nyears = 100\nint =   Yields.Forward(rand(Normal(μ,σ), years))\n\nlife = SingleLife(mortality = vbt2001.select[30], issue_age = 30)\n\nterm = 10\nLifeContingencies.A(lc, term) # around 0.055","category":"page"},{"location":"#Extending-example-to-use-autocorrelated-interest-rates","page":"Home","title":"Extending example to use autocorrelated interest rates","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"You can use autocorrelated interest rates - substitute the following in the prior example using the ability to self reference:","category":"page"},{"location":"","page":"Home","title":"Home","text":"σ = 0.01\ninitial_rate = 0.05\nvec = fill(initial_rate, years)\n\nfor i in 2:length(vec)\n    vec[i] = rand(Normal(vec[i-1], σ))\nend\n\nint = Yields.Forward(vec)","category":"page"},{"location":"#Premium-comparison-across-Mortality-Tables","page":"Home","title":"Premium comparison across Mortality Tables","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Compare the cost of annual premium, whole life insurance between multiple tables visually:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using LifeContingencies, MortalityTables, Plots\n\ntables = [\n    MortalityTables.table(\"1980 CET - Male Nonsmoker, ANB\"),\n    MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\"),\n    MortalityTables.table(\"2015 VBT Male Non-Smoker RR100 ANB\"),\n    ]\n\nissue_ages = 30:90\nint = Yields.Constant(0.05)\n\nwhole_life_costs = map(tables) do t\n    map(issue_ages) do ia\n        lc = LifeContingency(SingleLife(mortality = t.ultimate, issue_age = ia), int)\n        premium_net(lc)\n\n    end\nend\n\nplt = plot(ylabel=\"Annual Premium per unit\", xlabel=\"Issue Age\",\n           legend=:topleft, legendfontsize=8,size=(800,600))\n\nfor (i,t) in enumerate(tables)\n    plot!(plt,issue_ages,whole_life_costs[i], label=\"$(t.metadata.name)\")\nend\n\ndisplay(plt)","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Comparison of three different mortality tables' effect on insurance cost)","category":"page"},{"location":"#Joint-Life","page":"Home","title":"Joint Life","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"m1 = MortalityTables.table(\"1986-92 CIA – Male Smoker, ANB\")\nm2 = MortalityTables.table(\"1986-92 CIA – Female Nonsmoker, ANB\")\nl1 = SingleLife(mortality = m1.ultimate, issue_age = 40)\nl2 = SingleLife(mortality = m2.ultimate, issue_age = 37)\n\njl = JointLife(lives=(l1, l2), contingency=LastSurvivor(), joint_assumption=Frasier())\n\n\nInsurance(jl,Yields.Constant(0.05))      # whole life insurance\n...                                      # similar functions as shown in the first example above","category":"page"},{"location":"#Commutation-and-Unexported-Function-shorthand","page":"Home","title":"Commutation and Unexported Function shorthand","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Because it's so common to use certain variables in your own code, LifeContingencies avoids exporting certain variables/functions so that it doesn't collide with your own usage. For example, you may find yourself doing something like:","category":"page"},{"location":"","page":"Home","title":"Home","text":"a = ...\nb = ...\nresult = b - a","category":"page"},{"location":"","page":"Home","title":"Home","text":"If you imported using LifeContingencies and the package exported a (annuity_immediate) then you could have problems if you tried to do the above. To avoid this, we only export long-form functions like annuity_immediate. To utilize the shorthand, you can include them into your code's scope like so:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using LifeContingencies # brings all the default functions into your scope\nusing LifeContingencies: a, ä # also brings the short-form annuity functions into scope","category":"page"},{"location":"","page":"Home","title":"Home","text":"Or you can do the following:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using LifeContingencies # brings all the default functions into your scope\n... # later on in the code\nLifeContingencies.ä(...) # utilize the unexported function with the module name","category":"page"},{"location":"","page":"Home","title":"Home","text":"For more on module scoping, see the Julia Manual section.","category":"page"},{"location":"#Actuarial-notation-shorthand","page":"Home","title":"Actuarial notation shorthand","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"V => reserve_premium_net\nv => discount\nA => present value of Insurance\nä => present value of AnnuityDue\na => present value of AnnuityImmediate\nP => premium_net\nω => omega","category":"page"},{"location":"#Commutation-functions","page":"Home","title":"Commutation functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"l,\nD,\nM,\nN,\nC,","category":"page"},{"location":"#References","page":"Home","title":"References","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Life Insurance Mathematics, Gerber\nActuarial Mathematics and Life-Table Statistics, Slud\nCommutation Functions, MacDonald","category":"page"},{"location":"","page":"Home","title":"Home","text":"<script>\n    window.goatcounter = {\n        path: function(p) { return location.host + p }\n    }\n</script>\n<script data-goatcounter=\"https://juliaactuary.goatcounter.com/count\"\n        async src=\"//gc.zgo.at/count.js\"></script>","category":"page"}]
}
