using DataFrames, CSV, PlotlyJS

scenario = "base_WD_2050_nostock_hydrotst"
condition = "base2050_wd_NENA_csd"
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
#Technology ordered

ordered_tech = ["Coal","Nuc","NGCC","NGCC_CCS","NGCT","Hydro_res","Hydro_ror","Hydro_pump","Bio","BECCS","WindOn","WindOff","SolarPV","Battery","Other_peaker"]

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

Exist_agg_cap_df = aggregate_capdata(Exist_capacity)
End_agg_cap_df = aggregate_capdata(End_capacity)
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



#plot hydro power output --------------------------------------------------------#
#aggregrated 


agg_hydro_data = combine(groupby(filter(row -> in(row.Technology, ["Hydro_res","Hydro_ror"]), Output_power),[:Technology,:Zone]), names(Output_power, r"t\d+") .=> sum)
agg_hydro_pump_dc_data = combine(groupby(filter(row -> in(row.Technology, ["Hydro_pump"]), Output_power),[:Technology,:Zone]), names(Output_power, r"t\d+") .=> sum)
agg_hydro_pump_soc_data = combine(groupby(filter(row -> in(row.Technology, ["Hydro_pump"]), Output_es_soc_power),[:Technology,:Zone]), names(Output_power, r"t\d+") .=> sum)
agg_hydro_pump_c_data = combine(groupby(filter(row -> in(row.Technology, ["Hydro_pump"]), Output_es_c_power),[:Technology,:Zone]), names(Output_power, r"t\d+") .=> sum)


power_hydro_output_data_df = Dict(
    "agg_hydro_data" =>agg_hydro_data,
    "agg_hydro_pump_dc_data"=>agg_hydro_pump_dc_data,
    "agg_hydro_pump_soc_data"=>agg_hydro_pump_soc_data,
    "agg_hydro_pump_c_data" => agg_hydro_pump_c_data
)
#hours=1:168
hours= 3625:3792#3625:3792#1:8760 #summer:3625:3792 #winter: 8401:8568

ordered_tech_power = ["Hydro_res","Hydro_ror","Hydro_pump"]
ordered_es_tech = ["Hydro_pump"]
function plot_hydro_power_output(data::Dict, ordered_tech_power::Vector,ordered_es_tech ::Vector, color_map::Dict,hours::UnitRange,zone::String)
    agg_es_dc_zone_data=select!(filter(row -> row.Zone in [zone], data["agg_hydro_pump_dc_data"]),Not(:Zone))
    agg_es_c_zone_data=select!(filter(row -> row.Zone in [zone], data["agg_hydro_pump_c_data"]),Not(:Zone))
    agg_zone_data=select!(filter(row -> row.Zone in [zone],agg_hydro_data),Not(:Zone))
    agg_es_soc_zone_data=select!(filter(row -> row.Zone in [zone], data["agg_hydro_pump_soc_data"]),Not(:Zone))
    plot_data= [[if (isempty(agg_zone_data[agg_zone_data[!,:Technology] .==tech,:])) filter!(!=(tech), ordered_es_tech )
            elseif (tech == "Battery") scatter(x=hours, y=-Vector(agg_es_c_zone_data[agg_es_c_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]),mode="lines",  line=attr(dash="dash"), line_color=color_map[tech],stackgroup="two", hoverinfo="x+y",name=tech*"_ch")
            elseif (tech == "Hydro_pump") scatter(x=hours, y=-Vector(agg_es_c_zone_data[agg_es_c_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]),mode="lines", line=attr(dash="dash"), line_color=color_map[tech],stackgroup="two", hoverinfo="x+y",name=tech*"_ch")
            else scatter(x=hours, y=Vector(agg_zone_data[agg_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]), mode="lines",line_color=color_map[tech], stackgroup="one", hoverinfo="x+y",name=tech)end 
            for tech in ordered_es_tech];[if (isempty(agg_zone_data[agg_zone_data[!,:Technology] .==tech,:])) filter!(!=(tech), ordered_tech_power)
            elseif (tech == "Battery") scatter(x=hours, y=Vector(agg_es_dc_zone_data[agg_es_dc_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]),mode="lines", line_color=color_map[tech],stackgroup="one", hoverinfo="x+y",name=tech*"_dis")
            elseif (tech == "Hydro_pump") scatter(x=hours, y=Vector(agg_es_dc_zone_data[agg_es_dc_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]),mode="lines", line_color=color_map[tech],stackgroup="one", hoverinfo="x+y",name=tech*"_dis")
            else scatter(x=hours, y=Vector(agg_zone_data[agg_zone_data[!,:Technology] .==tech,:][1,broadcast(x -> x + 1, collect(hours))]), mode="lines",line_color=color_map[tech], stackgroup="one", hoverinfo="x+y",name=tech)end 
            for tech in ordered_tech_power]]
    max_y_cap = maximum(sum, eachcol(agg_zone_data[:,2:end]))
    min_y_cap = maximum(sum, eachcol(agg_es_c_zone_data[:,2:end]))
    traces = GenericTrace[]
    for trace in plot_data
        push!(traces,trace)
    end
    return Plot(traces, 
                Layout(
                title="Power Generation from Different Hydro Sources in " * zone,
                xaxis_title="Time (Hours)",
                yaxis_title="Power Generation (MW)",
                yaxis_type="linear",
                yaxis_range=[-100,40000],  #[-100,1.1*max_y_cap]               #yaxis_range=[-10*min_y_cap,1.1*max_y_cap],
                showlegend=true,
                barmode="stack", dpi=600)
    )
end
#||tech == "Hydro_pump"

plot_hydro_power_output(power_hydro_output_data_df, ordered_tech_power, ordered_es_tech, color_map, hours,"QC")
savefig(plot_power_output(power_hydro_output_data_df, ordered_tech_power, ordered_es_tech, color_map, hours,"QC"), condition*".png")


