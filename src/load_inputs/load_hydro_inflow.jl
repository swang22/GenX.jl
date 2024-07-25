@doc raw"""
	load_hydro_inflow!(setup::Dict, path::AbstractString, inputs::Dict)

Read water inflow for hydro power resources
"""
function load_hydro_inflow!(setup::Dict, path::AbstractString, inputs::Dict)

	# Hourly capacity factors
	data_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    if setup["TimeDomainReduction"] == 1  && time_domain_reduced_files_exist(data_directory)
        my_dir = data_directory
	else
        my_dir = path
	end
    filename = "Hydro_inflow.csv"
    hydro_inflow = load_dataframe(joinpath(my_dir, filename))
    #avg_inflow = mean([mean(skipmissing(hydro_inflow[:, col])) for col in names(hydro_inflow)[2:end]])

    #hydro resrouce for modeling water dynamic
    all_resource = inputs["RESOURCES"]
    hydro_resources = inputs["RESOURCES"][inputs["HYDRO_WD"]]

    existing_inflow = names(hydro_inflow)
    for r in all_resource
        if r ∉ existing_inflow
            #@info "assuming water average inflow for resource $r."
            @info "assuming water inflow 0 for resource $r."
            ensure_column!(hydro_inflow, r, 0)
        end
    end

	# Reorder DataFrame to R_ID order (order provided in Generators_data.csv)
	select!(hydro_inflow, [:Time_Index; Symbol.(all_resource) ])
    #print("Check")
	# Water inflow of each hydro resource
	inputs["pW_Inflow"] = transpose(Matrix{Float64}(hydro_inflow[1:inputs["T"],2:(inputs["G"]+1)]))
    #inputs["pW_Inflow"] = hydro_inflow[1:inputs["T"],2:(size(hydro_resources)[1]+1)]
	println(filename * " Successfully Read!")
end
