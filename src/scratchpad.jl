using LifeContingencies
using MortalityTables
using Dates
using DataFrames

mort_table_name = "2012 IAM Period Table – Male, ANB"
improv_table = "Projection Scale G2 – Male, ANB"
iss_date = Date(2017,09,01)
val_date = Date(2017,12,31)
issue_age = 65
annual_income = 12000
deferral_period = 0
benefit_period = 120
interest_rate = 0.04

# Not used because table name provides 
# sex = :M
# projection_scale = :G2
# age_rule = :ANB

tables = MortalityTables.tables()

mort = tables[mort_table_name]
imp = tables[improv_table]

table_end = omega(mort)

# the projection scale table only goes to age 105, wheras we want  through age 120
function imp_rate(table,age)
    if age > lastindex(table)
        return 0.0
    else
        return table[age]
    end
end

SRA = map(0:(table_end - issue_age)) do time
    
    att_age = issue_age + time
    
    if time > 1 
        imp_factor = prod(map(age -> 1 - imp_rate(imp,age),issue_age:(att_age-1)))
    else
        imp_factor = 1.0
    end
    
    # returned values for each time
    
    (
        att_age = att_age,
        t=time,
        q=mort[att_age],
        imp_factor = imp_factor,
        q_imp = mort[att_age] * imp_factor,
        
    )
end

### A type to handle life contingent maths via the LifeContingencies package
ins = LifeContingency(
    SingleLife(
        mort = UltimateMortality([x.q_imp for x in SRA],start_age = issue_age), # mort is indexed by attained age, not starting at 1
        issue_age = issue_age
    ),
    InterestRate(interest_rate)
)


ä(ins,55) * annual_income
sum(LifeContingencies.APV.(ins,1:55) * 12000)



ℓ₁ = [43302,42854,42081,41351,40050]
ℓ₂ = [47260,47040,46755,46500,46227]

ps₁ =  ℓ₁ ./ ℓ₁[1]
qs₁ = [1 - ps₁[t] / ps₁[t - 1] for t in 2:5 ] 

ps₂ =  ℓ₂ ./ ℓ₂[1]
qs₂ = [1 - ps₂[t] / ps₂[t - 1] for t in 2:5 ] 

m1 = UltimateMortality(qs₁, start_age=65)
m2 = UltimateMortality(qs₂, start_age=60)


l1 = SingleLife(mort = m1, issue_age = 65)
l2 = SingleLife(mort = m2, issue_age = 60)

jl = JointLife(lives=(l1, l2), contingency = LastSurvivor(), joint_assumption=Frasier())



ins = LifeContingency(jl,InterestRate(0.05))
ins_l1 = LifeContingency(jl.lives[1],InterestRate(0.05))
ins_l2 = LifeContingency(jl.lives[2],InterestRate(0.05))
# problem 9.1.f