using DataFrames, CSV

input_folder = "load_adjust"
scenario = "Base"
path_genin = joinpath(pwd(),input_folder)#dirname(pwd())
#path_genout = joinpath(pwd(),"Results_"*scenario)


#read input data##############
Input_original_load_df = CSV.read(joinpath(path_genin,"Load_data.csv"),DataFrame)
Input_delta_load_df = CSV.read(joinpath(path_genin,"DataCenter_Load_data.csv"),DataFrame)
Input_original_load_df[:,10:73] .+= Input_delta_load_df[:,2:end]

CSV.write(joinpath(input_folder, scenario*"Load_data.csv"), Input_original_load_df, writeheader=true)


