using ActuarialScience
using Test
using Distributions

# assumes embedded 'testMort' table
t = MortalityTable(maleMort)

@test 0.00699 ≈ qx(t,0)
@test 0.000447 ≈ qx(t,1)
@test 1000.0 == lx(t,0)
@test 993.010 ≈ lx(t,1)
@test 1000.0-1000*qx(t,0) ≈ lx(t,1)
@test 992.5661245 ≈ lx(t,2)
@test 120 == w(t)
@test 0 == dx(t,150)
@test 6.99 ≈ dx(t,0)
@test 76.8982069 ≈ ex(t,0)
@test tpx(t,15,3) >= tpx(t,15,4)
@test tqx(t,16,2) >= tqx(t,15,2)
@test 0 <= ex(t,15)
@test 0.003664839851 ≈ tpx(t,22,80)

################
# Interest Rates
################

## functional interest rate
i1 = InterestRate((x -> .05))

@test 1/(1.05) == v(i1)
@test 1/(1.05) == vx(i1,1)
@test 1/(1.05^2) == tvx(i1,2,1)
@test .05 == i(i1,1)

## vector interest rate

i2 = InterestRate([.05,.05,.05])
@test 1/(1.05) == v(i2)
@test 1/(1.05) == vx(i2,1)
@test 1/(1.05^2) == tvx(i2,2,1)

## real interest rate

i3 = InterestRate(.05)

@test 1/(1.05) == v(i3)
@test 1/(1.05) == vx(i3,1)
@test 1/(1.05^2) == tvx(i3,2,1)
@test 1/(1.05^120) ≈ tvx(i3,120,1)

## Stochastic interest rate
i4 = InterestRate((x -> rand(Normal(0.05,0.01))))
i5 = InterestRate((x -> rand(Normal(i(i5,-1),0.01))), .05)

@test v(i4) > 0
@test v(i5) > 0
@test tvx(i4,120,1) > 0
@test tvx(i5,120,1) > 0

## Insurance
ins = LifeInsurance(t,i3)
@test  Ax(ins,0) ≈ 0.04223728223

@test  Axn(ins,26,1) ≈ 0.001299047619
@test  Ax(ins,26) ≈ 0.1082172434
@test äx(ins,26) >= 0.0

## TODO: more robust tests because current calculations are probably off

