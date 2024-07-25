@doc raw"""
    load_hydro_system!(path::AbstractString, inputs::Dict, setup::Dict)

Read indexed set J that represeting hydro system stream
"""
function load_hydro_system!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Hydro_system.csv"
    df = load_dataframe(joinpath(path, filename))
    HYDRO_WD = inputs["HYDRO_WD"]
    mapping_tab = Dict(zip([y for y in HYDRO_WD],[filter(row -> row["R_ID"]== y, df) for y in HYDRO_WD]))
    inputs["J"] = Dict(zip([y for y in HYDRO_WD],parse.(Int,[name for name in names(mapping_tab[y]) if any(x -> x == 1, mapping_tab[y][!, name])]) for y in HYDRO_WD))

    println(filename * " Successfully Read!")
end
