n_steps =10
I=1
C1=3.25
R1 = 97.5
dV = [0] * n_steps
dt = 2**(-10)
print("dt = ", dt)
c1=1/C1
a1 = 1/(R1*C1)

print("n_steps = ", n_steps, "\n -------------------- " )

print(f"The value for c1 used is {c1} and the value for a1 is {a1}")

stage1_t1 = I * c1
stage1_t2 = a1 * dV[0]
stage2_t3 = (stage1_t1 - stage1_t2)*dt

dV[1] = dV[0] + stage2_t3
print(f"AT 0 \n\n")
print(f"At 1 : Stage 1 term 1: {stage1_t1}")
print(f"Stage 1 term 2: {stage1_t2}")
print(f"Stage 2 term 3: {stage2_t3}")
print(f"Stage 2 dV[1]: {dV[1]}")
# From GTK Wave
stg1_t1_gtk = "000001001110110001000000000000000000000000000000000000000000000" # CORRECT 4EN57
stg1_t2_gtk = "000000000000000000000000000000000000000000000000000000000000000" # CORRECT 11EN51

stg2_t3_gtk = "000000000000000000000010011101100010000000000000" # CORRECT 11EN51

## k=1
stage1_t1 = I * c1
stage1_t2 = a1 * dV[1]
stage2_t3 = (stage1_t1 - stage1_t2)*dt

dV[2] = dV[1] + stage2_t3
print(f"AT 0 \n\n")
print(f"At 2 : Stage 1 term 1: {stage1_t1}")
print(f"Stage 1 term 2: {stage1_t2}")
print(f"Stage 2 term 3: {stage2_t3}")
print(f"Stage 2 dV[2]: {dV[2]}")
# From GTK Wave


## New -- 0.000300467014312744
c1 = 0.3076629638671875
a1 = 0.003155708312988281

dV = [0] * n_steps
I = 1

dV[1] = dV[0] + (I * c1 - a1 * dV[0]) * dt
print(f"New dV[1]: {dV[1]}")

# Step 2 values
# 
a1 = 0.003595829010009766
c1 = 0.2984771728515625


dV[2] = dV[1] + (I * c1 - a1 * dV[1]) * dt
print(f"Alternative dV[2]: {dV[2]}")    #0.0.000591948628425598 in GTK simulation

# a1 and c1 remain unchanged for third step
dV[3] = dV[2] + (I * c1 - a1 * dV[2]) * dt
print(f"Alternative dV[3]: {dV[3]}")    #0.0.000883428125234786 in GTK simulation
