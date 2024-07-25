using DataFrames, CSV, PlotlyJS

scenario = "base_WD_2050_nostock_agg"
condition = "base_2050_agg_NYNElimited"
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

line_zone_map_dict = Dict(
    "1" => "NE",
    "2" => "NY",
    "3" => "QC",
    "4" => "ON",
    "5" => "AT"
)

#read input data##############
Input_network_df = CSV.read(joinpath(path_genin,"Network.csv"),DataFrame)
Input_network_df.Index = [string(i) for i in 1:size(Input_network_df.Network_Lines)[1]] 
transfer_zone_map_dict =Dict(row.Index => row.Network_Lines for row in eachrow(Input_network_df))
#read output data#
#flow
Output_flow=CSV.read(joinpath(path_genout,"flow.csv"),DataFrame)
Output_flow = Output_flow[2:end, :]
new_names = [get(transfer_zone_map_dict, name, name) for name in names(Output_flow)]
new_names = map(x -> String(string(x)), new_names)
rename!(Output_flow, names(Output_flow) .=> new_names)


#price
Output_price=CSV.read(joinpath(path_genout,"prices.csv"),DataFrame)
new_names = [get(line_zone_map_dict, name, name) for name in names(Output_price)]
#new_names = map(x -> String(string(x)), new_names)
rename!(Output_price, names(Output_price) .=> new_names)

#Combine
Ouput_combined = hcat(Output_flow,Output_price)


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


function plot_power_transfer_duration_curve(df::DataFrame, transfer_col::String)
    sorted_transfers = sort(df[!, transfer_col], rev = true)
    x = 1:length(sorted_transfers)
    trace = scatter(x = x, y = sorted_transfers, mode = "lines+markers", name = "Power Transfer Duration Curve")
    
    layout = Layout(
        title = "Power Transfer Duration Curve "*transfer_col,
        xaxis_title = "Duration",
        yaxis_title = "Power Transfered (MW)",
        yaxis = attr(range = [minimum(sorted_transfers) * 0.9, maximum(sorted_transfers) * 1.1])
    )

    plot([trace], layout)
end

plot_power_transfer_duration_curve(Ouput_combined,"QC-NE")
#savefig(plot_power_output(power_output_data_df, ordered_tech_power, ordered_es_tech, color_map, hours), condition*".png")

function plot_power_transfer_prices_duration_curve(df::DataFrame, transfer_col::String, price_col::String)
    sort!(df, transfer_col, rev=true)
    sorted_transfers = df[!, transfer_col]
    sorted_prices = df[!, price_col]
    x = 1:length(sorted_transfers)
    trace_power = scatter(x = x, y = sorted_transfers, mode = "lines", name = "Power Transfered", yaxis = "y1")
    

    trace_price = scatter(x = x, y = sorted_prices, mode = "lines", name = "Price", yaxis = "y2"
)
    layout = Layout(
        title = "Power Transfer Duration Curve with Electricity Prices "*transfer_col,
        xaxis_title = "Duration",
        yaxis1 = attr(title = "Power Transfered (MW)"),
        yaxis2 = attr(title = price_col*" Prices (\$/MWh)", overlaying = "y", side = "right", range = [-1000,1000])
    )
    plot([trace_power, trace_price], layout)
end

plot_power_transfer_prices_duration_curve(Ouput_combined,"QC-NY","QC")

#price differences
function plot_power_transfer_prices_diff_duration_curve(df::DataFrame, transfer_col::String, price_col1::String, price_col2::String)
    sort!(df, transfer_col, rev=true)
    sorted_transfers = df[!, transfer_col]
    reference_prices = df[!, price_col1]
    sorted_prices = df[!, price_col2]-reference_prices
    combined_df = DataFrame([sorted_transfers,sorted_prices],:auto)
    rename!(combined_df , names(combined_df) .=> [transfer_col,price_col2])
    combined_df[!, transfer_col] = round.(combined_df[!, transfer_col], digits=1)
    sort!(combined_df, [transfer_col,price_col2], rev=true)
    sorted_transfers = combined_df[!, transfer_col]
    #print(combined_df)
    x = 1:length(sorted_transfers)
    trace_power = scatter(x = x, y = sorted_transfers, mode = "lines", name = "Power Transfered", yaxis = "y1")
    #sort!(combined_df, price_col2, rev=true)
    #print(combined_df[1,1]==combined_df[3,1])
    #print(combined_df[1:10,:])
    sorted_prices =  combined_df[!, price_col2]
    trace_price = scatter(x = x, y = sorted_prices, mode = "markers",  marker = attr(size = 2), name = "Price", yaxis = "y2")
    
    layout = Layout(
        title = "Power Transfer Duration Curve with Electricity Prices Differences "*transfer_col,
        xaxis_title = "Duration",
        yaxis1 = attr(title = "Power Transfered (MW)"),
        yaxis2 = attr(title = price_col2*"-"*price_col1*" Price Differences (\$/MWh)", overlaying = "y", side = "right", range = [-100,100])
        #yaxis2 = attr(title = price_col1*"-"*price_col2*" Price Differences (\$/MWh)", overlaying = "y", side = "right")
    )
    plot([trace_power, trace_price], layout)
end

plot_power_transfer_prices_diff_duration_curve(Ouput_combined,"QC-NE","QC","NE")
