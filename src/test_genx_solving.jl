##Test GenX
setup = configure_settings("D:\\Dropbox (MIT)\\MIT\\Q_hydro_study\\Model\\GenX\\Example_Systems\\NortheasternArea_HQ\\Settings\\genx_settings.yml")
inputs = load_inputs(setup,"D:\\Dropbox (MIT)\\MIT\\Q_hydro_study\\Model\\GenX\\Example_Systems\\NortheasternArea_HQ\\")
settings_path = "D:\\Dropbox (MIT)\\MIT\\Q_hydro_study\\Model\\GenX\\Example_Systems\\NortheasternArea_HQ\\Settings\\"
OPTIMIZER = configure_solver(setup["Solver"], settings_path)
EP = generate_model(setup, inputs, OPTIMIZER)
EP, solve_time = solve_model(EP, setup)