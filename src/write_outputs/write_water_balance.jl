function find_row_indices_by_value(df, column_name, value)
	return findall(df[!, column_name] .== value)[1]
end

function write_water_balance(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	J = inputs["J"]		#Indexed set of upstream hydro resources for hydro y
	SEG = inputs["SEG"] # Number of load curtailment segments
	HYDRO_WD = inputs["HYDRO_WD"]
	WD = size(inputs["HYDRO_WD"])[1]
	## Water balance for each zone
	# dfPowerBalance = Array{Any}
	Com_list = ["Inflow", "Water_Upstream_DIS","Water_Upstream_SP","Water_Discharge", "Water_Spill",
	    "Water_Bypass","Water_Stored"]
	dfWaterBalance = DataFrame(BalanceComponent = repeat(Com_list, outer = WD), Hydro_plant = repeat([hp for hp in dfGen[HYDRO_WD,:Resource]], inner = size(Com_list)[1]), AnnualSum = zeros(size(Com_list)[1] * WD))
	# rowoffset = 3
	waterbalance = zeros(WD * size(Com_list)[1], T) # following the same style of power/charge/storage/nse
	z=0
	W_ELE = value.(EP[:vW_ELE])
	W_SPILL = value.(EP[:vW_SPILL])
	for hp in dfGen[HYDRO_WD,:Resource]
		z += 1
		row_id = find_row_indices_by_value(dfGen,:Resource, hp)
		waterbalance[(z-1)*size(Com_list)[1]+1, :] = inputs["pW_Inflow"][row_id,:]
		waterbalance[(z-1)*size(Com_list)[1]+2, :] = sum(Array(W_ELE[J[row_id],:]), dims=1) 
		waterbalance[(z-1)*size(Com_list)[1]+3, :] = sum(Array(W_SPILL[J[row_id],:]), dims=1)
		#sum(value.(EP[:vW_SPILL][j,:]) for j in J[row_id], dim=1)
		waterbalance[(z-1)*size(Com_list)[1]+4, :] = -value.(EP[:vW_ELE][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+5, :] = -value.(EP[:vW_SPILL][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+6, :] = -value.(EP[:vW_BYPASS][row_id, :])
		waterbalance[(z-1)*size(Com_list)[1]+7, :] = value.(EP[:vW_STOR][row_id, :])
		#waterbalance[(z-1)*size(Com_list)[1]+10, :] = (((-1) * inputs["pW_Inflow"][:, z]))' # Transpose
	end
	if setup["ParameterScale"] == 1
		waterbalance *= ModelScalingFactor
	end
	dfWaterBalance.AnnualSum .= waterbalance * inputs["omega"]
	dfWaterBalance = hcat(dfWaterBalance, DataFrame(waterbalance, :auto))
	auxNew_Names = [Symbol("BalanceComponent"); Symbol("Hydro_plant"); Symbol("AnnualSum"); [Symbol("t$t") for t in 1:T]]
	rename!(dfWaterBalance,auxNew_Names)
	CSV.write(joinpath(path, "water_balance.csv"), dftranspose(dfWaterBalance, false), writeheader=false)
end
