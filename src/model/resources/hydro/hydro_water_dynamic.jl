@doc raw"""
	hydro_res_water!(EP::Model, inputs::Dict, setup::Dict)
This module defines the operational constraints for reservoir hydropower plants.
Hydroelectric generators with water storage reservoirs ($y \in \mathcal{W}$) are effectively modeled as energy storage devices that cannot charge from the grid and instead receive exogenous inflows to their storage reservoirs, reflecting stream flow inputs. For resources with unknown reservoir capacity ($y \in \mathcal{W}^{nocap}$), their operation is parametrized by their generation efficiency, $\eta_{y,z}^{down}$, and energy inflows to the reservoir at every time-step, represented as a fraction of the total power capacity,($\rho^{max}_{y,z,t}$).  In case reservoir capacity is known ($y \in \mathcal{W}^{cap}$), an additional parameter, $\mu^{stor}_{y,z}$, referring to the ratio of energy capacity to discharge power capacity, is used to define the available reservoir storage capacity.
**Storage inventory balance**
Reservoir hydro systems are governed by the storage inventory balance constraint given below. This constraint enforces that energy level of the reservoir resource $y$ and zone $z$ in time step $t$ ($\Gamma_{y,z,t}$) is defined as the sum of the reservoir level in the previous time step, less the amount of electricity generated, $\Theta_{y,z,t}$ (accounting for the generation efficiency, $\eta_{y,z}^{down}$), minus any spillage $\varrho_{y,z,t}$, plus the hourly inflows into the reservoir (equal to the installed reservoir discharged capacity times the normalized hourly inflow parameter $\rho^{max}_{y,z, t}$).
```math
\begin{aligned}
&\Gamma_{y,z,t} = \Gamma_{y,z,t-1} -\frac{1}{\eta_{y,z}^{down}}\Theta_{y,z,t} - \varrho_{y,z,t} + \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}  \hspace{.1 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}^{interior} \\
&\Gamma_{y,z,t} = \Gamma_{y,z,t+\tau^{period}-1} -\frac{1}{\eta_{y,z}^{down}}\Theta_{y,z,t} - \varrho_{y,z,t} + \rho^{max}_{y,z,t} \times \Delta^{total}_{y,z}  \hspace{.1 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}^{start}
\end{aligned}
```
We implement time-wrapping to endogenize the definition of the intial state prior to the first period with the following assumption. If time step $t$ is the first time step of the year then storage inventory at $t$ is defined based on last time step of the year. Alternatively, if time step $t$ is the first time step of a representative period, then storage inventory at $t$ is defined based on the last time step of the representative period. Thus, when using representative periods, the storage balance constraint for hydro resources does not allow for energy exchange between representative periods.
Note: in future updates, an option to model hydro resources with large reservoirs that can transfer energy across sample periods will be implemented, similar to the functions for modeling long duration energy storage in ```long_duration_storage.jl```.
**Ramping Limits**
The following constraints enforce hourly changes in power output (ramps down and ramps up) to be less than the maximum ramp rates ($\kappa^{down}_{y,z}$ and $\kappa^{up}_{y,z}$ ) in per unit terms times the total installed capacity of technology y ($\Delta^{total}_{y,z}$).
```math
\begin{aligned}
&\Theta_{y,z,t} + f_{y,z,t} + r_{y,z,t} - \Theta_{y,z,t-1} - f_{y,z,t-1} \leq \kappa^{up}_{y,z} \times \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
&\Theta_{y,z,t-1} + f_{y,z,t-1}  + r_{y,z,t-1} - \Theta_{y,z,t} - f_{y,z,t}\leq \kappa^{down}_{y,z} \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
Ramping constraints are enforced for all time steps except the first time step of the year or first time of each representative period when using representative periods to model grid operations.
**Power generation and stream flow bounds**
Electricity production plus total spilled power from hydro resources is constrained to always be above a minimum output parameter, $\rho^{min}_{y,z}$, to represent operational constraints related to minimum stream flows or other demands for water from hydro reservoirs. Electricity production is constrained by either the the net installed capacity or by the energy level in the reservoir in the prior time step, whichever is more binding. For the latter constraint, the constraint for the first time step of the year (or the first time step of each representative period) is implemented based on energy storage level in last time step of the year (or last time step of each representative period).
```math
\begin{aligned}
&\Theta_{y,z,t} + \varrho_{y,z,t}  \geq \rho^{min}_{y,z} \times \Delta^{total}_{y,z}
\hspace{2 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
\Theta_{y,t}  \leq \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
```math
\begin{aligned}
\Theta_{y,z,t} \leq  \Gamma_{y,t-1}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
**Reservoir energy capacity constraint**
In case the reservoir capacity is known ($y \in W^{cap}$), then an additional constraint enforces the total stored energy in each time step to be less than or equal to the available reservoir capacity. Here, the reservoir capacity is defined multiplying the parameter, $\mu^{stor}_{y,z}$ with the available power capacity.
```math
\begin{aligned}
\Gamma_{y,z, t} \leq \mu^{stor}_{y,z}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}^{cap}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
"""

### Notes ###
## 1. The current simulation of Water dynamic is modeled on hourly basis and for 8760 time steps
## 2. The relationship of reservior water volume stored (m3) has not been well estibilshed with reservior energy stored (MWh) due to missing hydraulic head of reservior 


function hydro_res_water!(EP::Model, inputs::Dict, setup::Dict)

	println("Hydro Reservoir Water Dynamic Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)
	Z = inputs["Z"]     # Number of zones
	D = [d for d in 1:24:T]			#First hour of day 
	J = inputs["J"]		#Indexed set of upstream hydro resources for hydro y
	p = inputs["hours_per_subperiod"] 	# total number of hours per subperiod

	HYDRO_WD = inputs["HYDRO_WD"]	# Set of all reservoir hydro resources, used for common constraints with water dynamic
	HYDRO_LRES = inputs["HYDRO_LRES"]	# Set of large reservoir hydro resources
	HYDRO_SRES = inputs["HYDRO_SRES"]	# Set of small reservoir hydro resources, intra-day reseervoir
	HYDRO_RoR = inputs["HYDRO_RoR_WD"]	# Set of run-of-river hydro resources with water dynamic
	
	#HYDRO_RES_KNOWN_CAP = inputs["HYDRO_RES_KNOWN_CAP"] # Reservoir hydro resources modeled with unknown reservoir energy capacity

    # These variables are used in the ramp-up and ramp-down expressions
    reserves_term = @expression(EP, [y in HYDRO_WD, t in 1:T], 0)
    regulation_term = @expression(EP, [y in HYDRO_WD, t in 1:T], 0)

    if setup["Reserves"] > 0
        HYDRO_RES_REG = intersect(HYDRO_WD, inputs["REG"]) # Set of reservoir hydro resources with regulation reserves
        HYDRO_RES_RSV = intersect(HYDRO_WD, inputs["RSV"]) # Set of reservoir hydro resources with spinning reserves
        #println([HYDRO_RES_REG,HYDRO_RES_RSV])
		regulation_term = @expression(EP, [y in HYDRO_WD, t in 1:T],
                           y ∈ HYDRO_RES_REG ? EP[:vREG][y,t] - EP[:vREG][y, hoursbefore(p, t, 1)] : 0)
		reg_term = @expression(EP, [y in HYDRO_WD, t in 1:T],
                           y ∈ HYDRO_RES_REG ? EP[:vREG][y,t] : 0)
		reserves_term = @expression(EP, [y in HYDRO_WD, t in 1:T],
                           y ∈ HYDRO_RES_RSV ? EP[:vRSV][y,t] : 0)
    end

	### Variables ###

	# Reservoir hydro storage level of resource "y" at hour "t" [MWh] on zone "z" - unbounded
	#@variable(EP, vS_HYDRO[y in setdiff(HYDRO_WD,HYDRO_RoR), t=1:T] >= 0)
	
	# Reservoir hydro storage level of resource "y" at hour "t" [m3] on zone "z" - unbounded
	@variable(EP, vW_STOR[y in HYDRO_WD,  t=1:T] >= 0)#z=1:Z,
	
	# Hydro reservoir overflow for discharge (generating electricity) variable
	@variable(EP, vW_ELE[y in HYDRO_WD,  t=1:T] >= 0)

	# Hydro reservoir overflow (water spill) variable
	@variable(EP, vW_SPILL[y in HYDRO_WD, t=1:T] >= 0)
	
	# Hydro reservoir bypass flow (water not used by following reservior) variable
	@variable(EP, vW_BYPASS[y in HYDRO_WD, t=1:T] >= 0)
	
	### Expressions ###

	## Water Balance Expressions ##
	#Large Reservoir
	@expression(EP, eWaterBalanceLargeHydroRes[t=1:T, z=1:Z],
		sum(EP[:vW_STOR][y,t] for y in intersect(HYDRO_LRES, dfGen[(dfGen[!,:Zone].==z),:R_ID])))

	#EP[:eWaterBalance_LRES] += eWaterBalanceLargeHydroRes #To do: use this for water balance check

	# Capacity Reserves Margin policy Reduntant
	#if setup["CapacityReserveMargin"] > 0
	#	@expression(EP, eCapResMarBalanceHydro[res=1:inputs["NCapacityReserveMargin"], t=1:T], sum(dfGen[y,Symbol("CapRes_$res")] * EP[:vP][y,t]  for y in HYDRO_WD))
	#	EP[:eCapResMarBalance] += eCapResMarBalanceHydro
	#end

	### Constratints ###
	### Water Balance Constraints to large reservoir hydro (y in set HYDRO_LRES) ###
	# Water stored in reservoir at end of each other hour is equal to energy at end of prior hour less generation and spill and + river inflows and upstream reservoir overflow in the current hour
	@constraint(EP, cWaterInventoryBalanceLRES[y in union(HYDRO_LRES,HYDRO_SRES), t in 1:T], (EP[:vW_STOR][y,t] - EP[:vW_STOR][y, hoursbefore(p, t, 1)])/3600 == inputs["pW_Inflow"][y,t] + sum(EP[:vW_ELE][j,t] + EP[:vW_SPILL][j,t] for j in J[y]) - EP[:vW_ELE][y,t] - EP[:vW_SPILL][y,t] - EP[:vW_BYPASS][y,t])
	#union(HYDRO_LRES,HYDRO_SRES)
	### Water Balance Constraints to small reservoir hydro (y in set HYDRO_SRES) ###
	@constraint(EP, cWaterInventoryBalanceSRES[y in HYDRO_SRES, d in D], 0 == sum(inputs["pW_Inflow"][y,t] + sum(EP[:vW_ELE][j,t] + EP[:vW_SPILL][j,t] for j in J[y]) - EP[:vW_ELE][y,t] - EP[:vW_SPILL][y,t] - EP[:vW_BYPASS][y,t] for t in d:d+23))

	### Water Balance Constraints to run-of-river hydro (y in set HYDRO_ROR) ###
	@constraint(EP, cWaterInventoryBalanceRoR[y in HYDRO_RoR, t in 1:T], 0 == inputs["pW_Inflow"][y,t] + sum(EP[:vW_ELE][j,t] + EP[:vW_SPILL][j,t] for j in J[y]) - EP[:vW_ELE][y,t] - EP[:vW_SPILL][y,t] - EP[:vW_BYPASS][y,t])

	### Water Flow Constraints commmon to all reservoir hydro (y in set HYDRO_WD) ###
	#Water level limit
	Billion_cov = 10^9
	@constraints(EP, begin
		#Water spillage limit
		cSpillLimit[y in HYDRO_WD,t in 1:T], EP[:vW_SPILL][y,t] <= dfGen[y,:pW_Spill_Max_m3_per_s]
		#Water discharge limit
		cDischargeLimit[y in HYDRO_WD,t in 1:T], EP[:vW_ELE][y,t] <= dfGen[y,:pW_Discharge_Max_m3_per_s]#discharge limit should be less than nameplate capacity

		cUpLimit[y in HYDRO_WD,t in 1:T], EP[:vW_STOR][y,t] <= dfGen[y,:pW_lvl_Max_Billion_m3]*Billion_cov
		cDnLimit[y in HYDRO_WD,t in 1:T], EP[:vW_STOR][y,t] >= dfGen[y,:pW_lvl_Min_Billion_m3]*Billion_cov
		#Intial water level limit
		cIntialLimit[y in HYDRO_WD,[1]], EP[:vW_STOR][y,1] == dfGen[y,:pW_lvl_0_Billion_m3]*Billion_cov
		cEndLimit[y in HYDRO_WD,[T]], EP[:vW_STOR][y,T] ==  EP[:vW_STOR][y,1]
		#Water ramp
		cwRampUp[y in union(HYDRO_LRES,HYDRO_SRES), t in 2:T], EP[:vW_STOR][y,T] - EP[:vW_STOR][y, hoursbefore(p,t,1)] <= dfGen[y,:wRamp_Up_Percentage]*dfGen[y,:pW_lvl_Max_Billion_m3]*Billion_cov
        cwRampDown[y in union(HYDRO_LRES,HYDRO_SRES), t in 2:T], EP[:vW_STOR][y, hoursbefore(p,t,1)] - EP[:vW_STOR][y,t] <= dfGen[y,:wRamp_Dn_Percentage]*dfGen[y,:pW_lvl_Max_Billion_m3]*Billion_cov
	end)
	### Power Constraints commmon to all reservoir hydro (y in set HYDRO_WD) ###
	if setup["Reserves"] > 0
		@constraints(EP, begin
		### NOTE: time coupling constraints in this block do not apply to first hour in each sample period;
			
			#Power generation limit
			cPowerGenLimit[y in HYDRO_WD, t in 1:T], EP[:vP][y,t] + reg_term[y,t] + reserves_term[y,t] == inputs["pPF"][y]*EP[:vW_ELE][y,t]
			#Power stored
			#cPowerStored[y in setdiff(HYDRO_WD, HYDRO_RoR), t in 1:T], EP[:vS_HYDRO][y,t] == inputs["pPF"][y]* EP[:vW_STOR][y,t]
			#Power spill
			#cPowerSpill[y in setdiff(HYDRO_WD, HYDRO_RoR), t in 1:T], EP[:vSPILL][y,t] == inputs["pPF"][y]* EP[:vW_SPILL][y,t]
			# Maximum ramp up and down 
			## Reduntant as it already shown in hydro_res
			
			#cRampUp[y in HYDRO_WD, t in 1:T], EP[:vP][y,t] + regulation_term[y,t] + reserves_term[y,t] - EP[:vP][y, hoursbefore(p,t,1)] <= dfGen[y,:Ramp_Up_Percentage]*EP[:eTotalCap][y]
			#cRampDown[y in HYDRO_WD, t in 1:T], EP[:vP][y, hoursbefore(p,t,1)] - EP[:vP][y,t] - regulation_term[y,t] + reserves_term[y, hoursbefore(p,t,1)] <= dfGen[y,:Ramp_Dn_Percentage]*EP[:eTotalCap][y]

		end)
	else
		@constraints(EP, begin

			cPowerGenLimit[y in HYDRO_WD, t in 1:T], EP[:vP][y,t]  == inputs["pPF"][y]*EP[:vW_ELE][y,t]

		end)
	end

	#Only RoR_WD
	@expression(EP, ePowerBalanceHydroWD[t=1:T, z=1:Z],
		sum(EP[:vP][y,t] for y in intersect(HYDRO_RoR, dfGen[(dfGen[!,:Zone].==z),:R_ID])))#hydro include the hydro_ror with WD
	
	EP[:ePowerBalance] += ePowerBalanceHydroWD
	### Constraints to limit maximum energy in storage based on known limits on reservoir energy capacity (only for HYDRO_RES_KNOWN_CAP)
	# Maximum energy stored in reservoir must be less than energy capacity in all hours - only applied to HYDRO_RES_KNOWN_CAP
	#@constraint(EP, cHydroMaxEnergy[y in HYDRO_RES_KNOWN_CAP, t in 1:T], EP[:vS_HYDRO][y,t] <= dfGen[y,:Hydro_Energy_to_Power_Ratio]*EP[:eTotalCap][y])
	
	### Constraints to limit maximum water in storage based on known limits on reservoir water capacity (only for HYDRO_RES_KNOWN_CAP)
	# Maximum water stored in reservoir must be less than energy water in all hours - only applied to HYDRO_RES_KNOWN_CAP
	#@constraint(EP, cHydroMaxwater[y in HYDRO_RES_KNOWN_CAP, t in 1:T], EP[:vW_STOR][y,t] <= dfGen[y,:Hydro_Energy_to_Power_Ratio]*EP[:eTotalCap][y])
	
	#Reserves considered in hydro_res:
	#if setup["Reserves"] == 1
		### Reserve related constraints for ror_wd resources , if used
	#	hydro_res_wd_reserves!(EP, inputs)
	#end
	## Reduntant as it already shown in hydro_res ##

	##CO2 Polcy Module Hydro Res Generation by zone
	#@expression(EP, eGenerationByHydroRes[z=1:Z, t=1:T], # the unit is GW
	#	sum(EP[:vP][y,t] for y in intersect(HYDRO_WD, dfGen[dfGen[!,:Zone].==z,:R_ID]))
	#)
	#EP[:eGenerationByZone] += eGenerationByHydroRes

end
#Notes: the regulation and spining have already been considered in hydro_res, which is the same as for WD hydro

@doc raw"""
	hydro_res_wd_reserves!(EP::Model, inputs::Dict)
This module defines the modified constraints and additional constraints needed when modeling operating reserves
**Modifications when operating reserves are modeled**
When modeling operating reserves, the constraints regarding maximum power flow limits are modified to account for procuring some of the available capacity for frequency regulation ($f_{y,z,t}$) and "updward" operating (or spinning) reserves ($r_{y,z,t}$).
```math
\begin{aligned}
 \Theta_{y,z,t} + f_{y,z,t} +r_{y,z,t}  \leq  \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t\in \mathcal{T}
\end{aligned}
```
The amount of downward frequency regulation reserves cannot exceed the current power output.
```math
\begin{aligned}
 f_{y,z,t} \leq \Theta_{y,z,t}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
The amount of frequency regulation and operating reserves procured in each time step is bounded by the user-specified fraction ($\upsilon^{reg}_{y,z}$,$\upsilon^{rsv}_{y,z}$) of nameplate capacity for each reserve type, reflecting the maximum ramp rate for the hydro resource in whatever time interval defines the requisite response time for the regulation or reserve products (e.g., 5 mins or 15 mins or 30 mins). These response times differ by system operator and reserve product, and so the user should define these parameters in a self-consistent way for whatever system context they are modeling.
```math
\begin{aligned}
f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T} \\
r_{y,z, t} \leq \upsilon^{rsv}_{y,z}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{W}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
"""
function hydro_res_wd_reserves!(EP::Model, inputs::Dict)

	println("Hydro Reservoir (Water Dynamic) Reserves Module")

	dfGen = inputs["dfGen"]

	T = inputs["T"]     # Number of time steps (hours)

	HYDRO_WD = inputs["HYDRO_RoR_WD"]#only for RoR

	HYDRO_RES_REG_RSV = intersect(HYDRO_WD, inputs["REG"], inputs["RSV"]) # Set of reservoir hydro resources with both regulation and spinning reserves

	HYDRO_RES_REG = intersect(HYDRO_WD, inputs["REG"]) # Set of reservoir hydro resources with regulation reserves
	HYDRO_RES_RSV = intersect(HYDRO_WD, inputs["RSV"]) # Set of reservoir hydro resources with spinning reserves

	HYDRO_RES_REG_ONLY = setdiff(HYDRO_RES_REG, HYDRO_RES_RSV) # Set of reservoir hydro resources only with regulation reserves
	HYDRO_RES_RSV_ONLY = setdiff(HYDRO_RES_RSV, HYDRO_RES_REG) # Set of reservoir hydro resources only with spinning reserves

	if !isempty(HYDRO_RES_REG_RSV)
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed capacity
			cWDRegulation[y in HYDRO_RES_REG_RSV, t in 1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*EP[:eTotalCap][y]
			cWDReserve[y in HYDRO_RES_REG_RSV, t in 1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]
			# Maximum discharging rate and contribution to reserves up must be less than power rating
			cWDMaxReservesUp[y in HYDRO_RES_REG_RSV, t in 1:T], EP[:vP][y,t]+EP[:vREG][y,t]+EP[:vRSV][y,t] <= EP[:eTotalCap][y]
			# Maximum discharging rate and contribution to regulation down must be greater than zero
			cWDMaxReservesDown[y in HYDRO_RES_REG_RSV, t in 1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= 0
		end)
	end

	if !isempty(HYDRO_RES_REG_ONLY)
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed capacity
			cWDRegulation[y in HYDRO_RES_REG_ONLY, t in 1:T], EP[:vREG][y,t] <= dfGen[y,:Reg_Max]*EP[:eTotalCap][y]
			# Maximum discharging rate and contribution to reserves up must be less than power rating
			cWDMaxReservesUp[y in HYDRO_RES_REG_ONLY, t in 1:T], EP[:vP][y,t]+EP[:vREG][y,t] <= EP[:eTotalCap][y]
			# Maximum discharging rate and contribution to regulation down must be greater than zero
			cWDMaxReservesDown[y in HYDRO_RES_REG_ONLY, t in 1:T], EP[:vP][y,t]-EP[:vREG][y,t] >= 0
		end)
	end

	if !isempty(HYDRO_RES_RSV_ONLY)
		@constraints(EP, begin
			# Maximum storage contribution to reserves is a specified fraction of installed capacity
			cWDReserve[y in HYDRO_RES_RSV_ONLY, t in 1:T], EP[:vRSV][y,t] <= dfGen[y,:Rsv_Max]*EP[:eTotalCap][y]
			# Maximum discharging rate and contribution to reserves up must be less than power rating
			cWDMaxReservesUp[y in HYDRO_RES_RSV_ONLY, t in 1:T], EP[:vP][y,t]+EP[:vRSV][y,t] <= EP[:eTotalCap][y]
		end)
	end

end
