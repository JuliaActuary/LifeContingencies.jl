var documenterSearchIndex = {"docs":
[{"location":"#LifeContingencies.jl","page":"Home","title":"LifeContingencies.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"DocTestSetup = quote\n    using LifeContingencies\n    using Dates\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [LifeContingencies]","category":"page"},{"location":"#LifeContingencies.Contingency","page":"Home","title":"LifeContingencies.Contingency","text":"Contingency()\n\nAn abstract type representing the different triggers for contingent benefits. Available options to use include:\n\nLastSurvivor()\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.Frasier","page":"Home","title":"LifeContingencies.Frasier","text":"Frasier()\n\nThe assumption of independnt lives in a joint life calculation. Is a subtype of JointAssumption.\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.Insurance-Tuple{LifeContingency}","page":"Home","title":"LifeContingencies.Insurance","text":"Insurance(lc::LifeContingency; n=nothing)\nInsurance(life,interest; n=nothing)\n\nLife insurance with a term period of n. If n is nothing, then whole life insurance.\n\nIssue age is based on the issue_age in the LifeContingency lc.\n\nExamples\n\nins = Insurance(\n    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),\n    Yields.Constant(0.05),\n    n = 1\n) \n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.JointAssumption","page":"Home","title":"LifeContingencies.JointAssumption","text":"JointAssumption()\n\nAn abstract type representing the different assumed relationship between the survival of the lives on a JointLife. Available options to use include:\n\nFrasier()\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.JointLife","page":"Home","title":"LifeContingencies.JointLife","text":"struct JointLife\n    lives\n    contingency\n    joint_assumption\nend\n\nA `Life` object containing the necessary assumptions for contingent maths related to a joint life insurance. Use with a `LifeContingency` to do many actuarial present value calculations.\n\nKeyword arguments:\n\nlives is a tuple of two SingleLifes\ncontingency default is LastSurvivor(). It is the trigger for contingent benefits. See ?Contingency. \njoint_assumption Default value is Frasier(). It is the assumed relationship between the mortality of the two lives. See ?JointAssumption. \n\nExamples\n\nusing MortalityTables\nmort = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\nl1 = SingleLife(\n    mort       = mort.select[30], \n    issue_age  = 30          \n)\nl2 = SingleLife(\n    mort       = mort.select[30], \n    issue_age  = 30          \n)\n\njl = JointLife(\n    lives = (l1,l2),\n    contingency = LastSurvivor(),\n    joint_assumption = Frasier()\n)\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.LastSurvivor","page":"Home","title":"LifeContingencies.LastSurvivor","text":"LastSurvivor()\n\nThe contingency whereupon benefits are payable upon both lives passing. Is a subtype of Contingency\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.LifeContingency","page":"Home","title":"LifeContingencies.LifeContingency","text":"struct LifeContingency\n    life::Life\n\n\n\n\n\n","category":"type"},{"location":"#LifeContingencies.SingleLife","page":"Home","title":"LifeContingencies.SingleLife","text":"struct SingleLife\n    mort\n    issue_age::Int\n    alive::Bool\n    fractional_assump::MortalityTables.DeathDistribution\nend\n\nA Life object containing the necessary assumptions for contingent maths related to a single life. Use with a LifeContingency to do many actuarial present value calculations. \n\nKeyword arguments:\n\nmort pass a mortality vector, which is an array of applicable mortality rates indexed by attained age\nissue_age is the assumed issue age for the SingleLife and is the basis of many contingency calculations.\nalive Default value is true. Useful for joint insurances with different status on the lives insured.\nfractional_assump. Default value is Uniform(). This is a DeathDistribution from the MortalityTables.jl package and is the assumption to use for non-integer ages/times.\n\nExamples\n\nusing MortalityTables\nmort = MortalityTables.table(\"2001 VBT Residual Standard Select and Ultimate - Male Nonsmoker, ANB\")\n\nSingleLife(\n    mort       = mort.select[30], \n    issue_age  = 30          \n)\n\n\n\n\n\n","category":"type"},{"location":"#ActuaryUtilities.present_value-Tuple{Any}","page":"Home","title":"ActuaryUtilities.present_value","text":"present_value(Insurance)\n\nThe actuarial present value of the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.APV-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.APV","text":"APV(lc::LifeContingency,to_time)\n\nThe actuarial present value which is the survival times the discount factor for the life contingency.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.AnnuityDue-Tuple{Any, Any}","page":"Home","title":"LifeContingencies.AnnuityDue","text":"AnnuityDue(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)\nAnnuityDue(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)\n\nAnnuity due with the benefit period starting at start_time and ending after n periods with frequency payments per year of 1/frequency amount and a certain period with non-contingent payments. \n\nExamples\n\nins = AnnuityDue(\n    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),\n    Yields.Constant(0.05),\n    n = 1\n) \n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.AnnuityImmediate-Tuple{Any, Any}","page":"Home","title":"LifeContingencies.AnnuityImmediate","text":"AnnuityImmediate(lc::LifeContingency; n=nothing, start_time=0; certain=nothing,frequency=1)\nAnnuityImmediate(life, interest; n=nothing, start_time=0; certain=nothing,frequency=1)\n\nAnnuity immediate with the benefit period starting at start_time and ending after n periods with frequency payments per year of 1/frequency amount and a certain period with non-contingent payments. \n\nExamples\n\nins = AnnuityImmediate(\n    SingleLife(mort = UltimateMortality([0.5,0.5]),issue_age = 0),\n    Yields.Constant(0.05),\n    n = 1\n) \n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.C-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.C","text":"C(lc::LifeContingency, to_time)\n\nC_x is a retrospective actuarial commutation function which is the product of the discount factor and the difference in l (l_x).\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.D-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.D","text":"D(lc::LifeContingency, to_time)\n\nD_x is a retrospective actuarial commutation function which is the product of the survival and discount factor.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.M-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.M","text":"M(lc::LifeContingency, from_time)\n\nThe M_x actuarial commutation function where the from_time argument is x. Issue age is based on the issue_age in the LifeContingency lc.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.N-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.N","text":"N(lc::LifeContingency, from_time)\n\nN_x is a prospective actuarial commutation function which is the sum of the D (D_x) values from the given time to the end of the mortality table.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.benefit-Tuple{Insurance}","page":"Home","title":"LifeContingencies.benefit","text":"benefit(Insurance)\n\nThe unit benefit vector for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.cashflows-Tuple{Insurance}","page":"Home","title":"LifeContingencies.cashflows","text":"cashflows(Insurance)\n\nThe vector of decremented benefit cashflows for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.l-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.l","text":"l(lc::LifeContingency, to_time)\n\nl_x is a retrospective actuarial commutation function which is the survival up to a certain point in time. By default, will have a unitary basis (ie 1.0), but you can specify basis keyword argument to use something different (e.g. 1000 is common in the literature.)\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.premium_net-Tuple{LifeContingency}","page":"Home","title":"LifeContingencies.premium_net","text":"premium_net(lc::LifeContingency)\npremium_net(lc::LifeContingency,to_time)\n\nThe net premium for a whole life insurance (without second argument) or a term life insurance through to_time.\n\nThe net premium is based on 1 unit of insurance with the death benfit payable at the end of the year and assuming annual net premiums.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.probability-Tuple{Insurance}","page":"Home","title":"LifeContingencies.probability","text":"probability(Insurance)\n\nThe vector of contingent benefit probabilities for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.reserve_premium_net-Tuple{LifeContingency, Any}","page":"Home","title":"LifeContingencies.reserve_premium_net","text":" reserve_premium_net(lc::LifeContingency,time)\n\nThe net premium reserve at the end of year time.\n\n\n\n\n\n","category":"method"},{"location":"#LifeContingencies.timepoints-Tuple{Insurance}","page":"Home","title":"LifeContingencies.timepoints","text":"timepoints(Insurance)\n\nThe vector of times corresponding to the cashflow vector for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#MortalityTables.decrement-Tuple{LifeContingency, Any, Any}","page":"Home","title":"MortalityTables.decrement","text":"decrement(lc::LifeContingency,to_time)\ndecrement(lc::LifeContingency,from_time,to_time)\n\nReturn the probablity of death for the given LifeContingency. \n\n\n\n\n\n","category":"method"},{"location":"#MortalityTables.omega-Tuple{LifeContingency}","page":"Home","title":"MortalityTables.omega","text":"omega(lc::LifeContingency)\nomega(l::Life)\nomega(i::InterestRate)\n\nLifes and LifeContingencys\n\nReturns the last defined timeperiod for both the interest rate and mortality table. Note that this is different than calling omega on a MortalityTable, which will give you the last `attainedage`.\n\nExample: if the LifeContingency has issue age 60, and the last defined attained age for the MortalityTable is 100, then omega of the MortalityTable will be 100 and omega of the  LifeContingency will be 40.\n\nInterestRates\n\nThe last period that the interest rate is defined for. Assumed to be infinite (Inf) for      functional and constant interest rate types. Returns the lastindex of the vector if      a vector type.\n\n\n\n\n\n","category":"method"},{"location":"#MortalityTables.survival-Tuple{Insurance}","page":"Home","title":"MortalityTables.survival","text":"survival(Insurance)\n\nThe survorship vector for the given insurance.\n\n\n\n\n\n","category":"method"},{"location":"#MortalityTables.survival-Tuple{LifeContingencies.Life}","page":"Home","title":"MortalityTables.survival","text":"surival(life)\n\nReturn a survival vector for the given life.\n\n\n\n\n\n","category":"method"},{"location":"#MortalityTables.survival-Tuple{LifeContingency, Any}","page":"Home","title":"MortalityTables.survival","text":"survival(lc::LifeContingency,from_time,to_time)\nsurvival(lc::LifeContingency,to_time)\n\nReturn the probablity of survival for the given LifeContingency. \n\n\n\n\n\n","category":"method"},{"location":"#Yields.discount-Tuple{Insurance}","page":"Home","title":"Yields.discount","text":"discount(Insurance)\n\nThe discount vector for the given insurance.\n\n\n\n\n\n","category":"method"}]
}
