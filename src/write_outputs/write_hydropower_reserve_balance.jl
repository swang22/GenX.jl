function find_row_indices_by_value(df, column_name, value)
	return findall(df[!, column_name] .== value)[1]
end

function write_hydro_power_reserve_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	J = inputs["J"]		#Indexed set of upstream hydro resources for hydro y
	SEG = inputs["SEG"] # Number of load curtailment segments
	HYDRO_WD = inputs["HYDRO_WD"]
	RSV = intersect(HYDRO_WD,inputs["RSV"])
	REG = intersect(HYDRO_WD,inputs["REG"])
	HYDRO_WD = intersect(HYDRO_WD,RSV,REG)
	WD = size(HYDRO_WD)[1]
	## Water balance for each zone
	# dfPowerBalance = Array{Any}
	Com_list = ["Power", "Rsv","Reg", "Power_discharged"]
	dfWaterBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = WD), Hydro_plant = repeat([hp for hp in dfGen[HYDRO_WD,:Resource]], inner = size(Com_list)[1]), AnnualSum = zeros(size(Com_list)[1] * WD))
	# rowoffset = 3
	waterbalance = zeros(WD * size(Com_list)[1], T) # following the same style of power/charge/storage/nse
	z=0
	power = value.(EP[:vP])
	rsv = value.(EP[:vRSV][RSV, :])
	reg = value.(EP[:vREG][REG, :])
	for hp in dfGen[HYDRO_WD,:Resource]
		z += 1
		row_id = find_row_indices_by_value(dfGen,:Resource, hp)
		waterbalance[(z-1)*size(Com_list)[1]+1, :] = value.(EP[:vP][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+2, :] = value.(EP[:vRSV][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+3, :] = value.(EP[:vREG][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+4, :] = inputs["pPF"][row_id]*value.(EP[:vW_ELE][row_id, :])
	end
	if setup["ParameterScale"] == 1
		waterbalance *= ModelScalingFactor
	end
	dfWaterBalance.AnnualSum .= waterbalance * inputs["omega"]
	dfWaterBalance = hcat(dfWaterBalance, DataFrame(waterbalance, :auto))
	auxNew_Names = [Symbol("BalanceComponent"); Symbol("Hydro_plant"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
	rename!(dfWaterBalance,auxNew_Names)
	CSV.write(joinpath(path, "hydropwer_reserve_balance.csv"), dftranspose(dfWaterBalance, false), writeheader=false)
end
