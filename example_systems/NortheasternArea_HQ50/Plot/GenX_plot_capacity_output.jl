using DataFrames, CSV, PlotlyJS

scenario = "base_WD_2050_nostock_agg"
condition = "base_2050_agg_alllimited"
path_genin = joinpath(pwd(),scenario)#dirname(pwd())
path_genout = joinpath(pwd(),"Results_"*condition)
#Function use for aggregrating generation data:
function aggregate_capdata(df)
	agg_df = combine(groupby(df, [:Technology,:Zone]),
	Symbol("Capacity (MW)") => sum,
    )
	rename!(agg_df, [Symbol("Capacity (MW)_sum")] .=>  [Symbol("Capacity (MW)")] )
	return agg_df
end
#color map https://discourse.julialang.org/t/discrete-colorbar-with-plotlyjs/80773
# https://docs.juliaplots.org/latest/generated/colorschemes/
color_map = Dict(
    "Coal" =>"Black",
    "Oil"=>"Bisque",
    "NGCT"=>"LightSlateGray",
    "Hydro_res"=>"MidnightBlue",
    "Hydro"=>"MidnightBlue",
    "Hydro_ror"=>"Blue",
    "Hydro_pump"=>"LightPurple",
    "Hydro_pump_c"=>"LightPurple",
    "Hydro_pump_dc"=>"LightPurple",
    "Nuc"=>"Orange",
    "MSW"=>"Saddlebrown",
    "Bio" =>"LightGreen",
    "BECCS" =>"Green",
    "Landfill_NG"=> "Gold",
    "NGCC"=>"SteelBlue",
    "NGCC_CCS"=>"LightSteelBlue",
    "NGST"=>"SteelBlue",
    "WindOn"=>"LightSkyBlue",
    "WindOff"=>"DarkSkyBlue",
    "SolarPV"=>"Yellow",
    "Battery" => "Purple",
    "Battery_dc" => "Purple",
    "Battery_c" => "Purple",
    "Other_peaker"=>"Red"
)

tech_acromy_map_dict = Dict(
    "Batteries" => "Battery",
    "Biomass" => "Bio",
    "BECCS" =>"BECCS",
    "Conventional Hydroelectric" => "Hydro",
    "Conventional Steam Coal" => "Coal",
    "Hydroelectric Pumped Storage" => "Hydro_pump",
    "Natural Gas Fired Combined Cycle" =>"NGCC",
    "Natural Gas Fired Combustion Turbine" =>"NGCT",
    "Natural Gas Steam Turbine" =>"NGST",
    "Nuclear"=>"Nuc",
    "Offshore Wind Turbine"=>"WindOff",
    "Onshore Wind Turbine"=>"WindOn",
    "Small Hydroelectric"=>"Hydro",
    "Run of river"=>"Hydro",
    "Solar Photovoltaic"=>"SolarPV",
    "NaturalGas_CCAvgCF_Moderate"=>"NGCC",
    "NaturalGas_CCAvgCF_CCS_Moderate"=>"NGCC_CCS"
)
#=
tech_acromy_map_dict = Dict(
    "Batteries" => "Battery",
    "Biomass" => "Bio",
    "BECCS" =>"BECCS",
    "Conventional Hydroelectric" => "Hydro_res",
    "Conventional Steam Coal" => "Coal",
    "Hydroelectric Pumped Storage" => "Hydro_pump",
    "Natural Gas Fired Combined Cycle" =>"NGCC",
    "Natural Gas Fired Combustion Turbine" =>"NGCT",
    "Natural Gas Steam Turbine" =>"NGST",
    "Nuclear"=>"Nuc",
    "Offshore Wind Turbine"=>"WindOff",
    "Onshore Wind Turbine"=>"WindOn",
    "Small Hydroelectric"=>"Hydro_ror",
    "Run of river"=>"Hydro_ror",
    "Solar Photovoltaic"=>"SolarPV",
    "NaturalGas_CCAvgCF_Moderate"=>"NGCC",
    "NaturalGas_CCAvgCF_CCS_Moderate"=>"NGCC_CCS"
)
=#
#Technology ordered

ordered_tech = ["Coal","Nuc","NGCC","NGCC_CCS","NGCT","Hydro","Hydro_pump","Bio","BECCS","WindOn","WindOff","SolarPV","Battery","Other_peaker"]

#read input data##############
Input_gen_df = CSV.read(joinpath(path_genin,"Generators_data.csv"),DataFrame)
re_tech_map_dict = Dict(zip(Input_gen_df.Resource, Input_gen_df.technology))
zone_map_dict = Dict(zip(Input_gen_df.Zone, Input_gen_df.region))
#read output data#
#capacity
Output_capacity=CSV.read(joinpath(path_genout,"capacity.csv"),DataFrame)
Output_capacity = Output_capacity[1:end-1, :]

Output_capacity.Technology = map(x -> get(re_tech_map_dict, x, x), Output_capacity.Resource)
Output_capacity.Technology =  map(x -> get(tech_acromy_map_dict, x, x), Output_capacity.Technology)
Output_capacity[!,:Zone] = parse.([Int],Output_capacity[!,:Zone])
Output_capacity.Zone =  map(x -> get(zone_map_dict, x, x), Output_capacity.Zone)


#Existing 
Exist_capacity = select(Output_capacity, [:Technology,:Zone,:StartCap])
rename!(Exist_capacity, [Symbol("StartCap")] .=>  [Symbol("Capacity (MW)")] )
#New_Build
New_capacity = select(Output_capacity, [:Technology,:Zone,:NewCap])
rename!(New_capacity, [Symbol("NewCap")] .=>  [Symbol("Capacity (MW)")] )
#Retirement
Ret_capacity = select(Output_capacity, [:Technology,:Zone,:RetCap])
rename!(Ret_capacity, [Symbol("RetCap")] .=>  [Symbol("Capacity (MW)")] )
#Final
End_capacity = select(Output_capacity, [:Technology,:Zone,:EndCap])
rename!(End_capacity, [Symbol("EndCap")] .=>  [Symbol("Capacity (MW)")] )

#Aggregrate by technology

Exist_agg_cap_df = aggregate_capdata(aggregate_capdata(Exist_capacity))
End_agg_cap_df = aggregate_capdata(aggregate_capdata(End_capacity))
New_agg_cap_df = aggregate_capdata(aggregate_capdata(New_capacity))
#Fill the missing ones:
function fill_gendf_zero(df)
    combins= DataFrame(Zone = repeat(unique(df[:,:Zone]), inner = length(unique(df[:,:Technology]))),
               Technology = vec(repeat(unique(df[:,:Technology]), outer = length(unique(df[:,:Zone])))))

    combins.Capacity = Array{Union{Missing,Float64}}(undef, size(combins)[1])
    rename!(combins, :Capacity => Symbol("Capacity (MW)"))

    df_combined = leftjoin(combins, df, on = [:Zone, :Technology], makeunique=true)
    df_combined[:,"Capacity (MW)"] = coalesce.(df_combined[:,"Capacity (MW)_1"], 0)
    #drop
    select!(df_combined, Not(Symbol("Capacity (MW)_1")))
    return df_combined
end


#plot capacity--------------------------------------------------------#
#plot(All_agg_cap_df, kind="bar",x=:Zone, y=Symbol("Capacity (MW)"), marker_color=:Color, symbol=:Technology, Layout(title="Generation Capacity Mix at 2022", barmode="stack", xaxis_categoryorder="category ascending"))
#https://plotly.com/julia/bar-charts/
function plot_cap_mix(df::DataFrame, ordered_tech::Vector, color_map::Dict,tt::String)
    agg_df = combine(groupby(df, [:Zone]),Symbol("Capacity (MW)") => sum)
    rename!(agg_df, Symbol("Capacity (MW)_sum") => "Cap")
    max_zone_cap = maximum(agg_df.Cap)

    return plot([bar(x=sort(unique(df[:,:Zone])), y= sort(filter(row -> row.Technology == ordered_tech[i],df), :Zone)[:,"Capacity (MW)"], marker_color=color_map[ordered_tech[i]], name=ordered_tech[i] ) for i in 1:size(ordered_tech)[1]], 
    Layout(title=tt, barmode="stack", 
    xaxis_categoryorder="category ascending", xaxis_title_text="Regions",
    yaxis_title_text="Capacity (MW)", 
    #yaxis_range=[0,1.1*max_zone_cap]
    yaxis_range=[0,110000]
    ))
end

plot_cap_mix(fill_gendf_zero(Exist_agg_cap_df), ordered_tech, color_map,  "Existing Generation Capacity Mix in 2022")
plot_cap_mix(fill_gendf_zero(End_agg_cap_df), ordered_tech, color_map,  "Optimized Generation Capacity Mix in 2050")
plot_cap_mix(fill_gendf_zero(New_agg_cap_df), ordered_tech, color_map,  "Installed New Generation Capacity in 2050")

#p
#plot capacity--------------------------------------------------------#
#power
Output_power= CSV.read(joinpath(path_genout,"power.csv"),DataFrame)
Output_es_soc_power =  CSV.read(joinpath(path_genout,"storage.csv"),DataFrame)
Output_es_c_power =  CSV.read(joinpath(path_genout,"charge.csv"),DataFrame)

#data processing
function power_data_reformate(df::DataFrame,tech_dict::Dict,tech_acromy_dict::Dict,zone_map_dict::Dict)
    Output_power = df
    re_tech_map_dict = tech_dict
    tech_acromy_map_dict = tech_acromy_dict
    zone_map_dict = zone_map_dict
    column_names = names(Output_power)  
    Output_power= permutedims(Output_power)
    Output_power = hcat(column_names, Output_power,makeunique=true)
    Output_power  = rename!(Output_power, Symbol.(Vector(Output_power[1,:])))[2:end-1,:]

    #replace the names
    Output_power.Technology = map(x -> get(re_tech_map_dict, x, x), Output_power.Resource)
    Output_power.Technology =  map(x -> get(tech_acromy_map_dict, x, x), Output_power.Technology)
    Output_power.Zone =  map(x -> get(zone_map_dict, x, x), Output_power.Zone)
    return Output_power
end

Output_power=power_data_reformate(Output_power,re_tech_map_dict,tech_acromy_map_dict,zone_map_dict)
Output_es_soc_power=power_data_reformate(Output_es_soc_power,re_tech_map_dict,tech_acromy_map_dict,zone_map_dict)
Output_es_c_power=power_data_reformate(Output_es_c_power,re_tech_map_dict,tech_acromy_map_dict,zone_map_dict)



