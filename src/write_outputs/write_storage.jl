@doc raw"""
	write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]
	STOR_ALL = inputs["STOR_ALL"]
	HYDRO_RES = inputs["HYDRO_RES"]
	FLEX = inputs["FLEX"]
	# Storage level (state of charge) of each resource in each time step
	dfStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	storagevcapvalue = zeros(G,T)

	if !isempty(inputs["STOR_ALL"])
	    storagevcapvalue[STOR_ALL, :] = value.(EP[:vS][STOR_ALL, :])
	end
	if !isempty(inputs["HYDRO_RES"])
		if setup["WaterDynamic"] != 1
			storagevcapvalue[HYDRO_RES, :] = value.(EP[:vS_HYDRO][HYDRO_RES, :])
		else
			HYDRO_RES_notWD = inputs["HYDRO_RES_notWD"]
			storagevcapvalue[HYDRO_RES_notWD, :] = value.(EP[:vS_HYDRO][HYDRO_RES_notWD, :])
			HYDRO_RES_WD = setdiff(HYDRO_RES,HYDRO_RES_notWD)
			storagevcapvalue[HYDRO_RES_WD, :] = value.(EP[:vS_HYDRO][HYDRO_RES_WD, :])
		end
	end
	if !isempty(inputs["FLEX"])
	    storagevcapvalue[FLEX, :] = value.(EP[:vS_FLEX][FLEX, :])
	end
	if setup["ParameterScale"] == 1
	    storagevcapvalue *= ModelScalingFactor
	end

	dfStorage = hcat(dfStorage, DataFrame(storagevcapvalue, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfStorage,auxNew_Names)
	CSV.write(joinpath(path, "storage.csv"), dftranspose(dfStorage, false), writeheader=false)
end
