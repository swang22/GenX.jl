@doc raw"""
	fix_integers(jump_model::Model)

inputs: jump_model - a model object containing that has been previously solved.

description: fixes the iteger variables ones the model has been solved in order to calculate approximations of dual variables

returns: none (modifies an existing-solved model in the memory). solve() must be run again to solve and getdual veriables

"""
function fix_integers(jump_model::Model)
	################################################################################
	## function fix_integers()
	##
	## inputs: jump_model - a model object containing that has been previously solved.
	##
	## description: fixes the iteger variables ones the model has been solved in order
	## to calculate approximations of dual variables
	##
	## returns: no result since it modifies an existing-solved model in the memory.
	## solve() must be run again to solve and getdual veriables
	##
	################################################################################
	values = Dict(v => value(v) for v in all_variables(jump_model))
	for v in all_variables(jump_model)
		if is_integer(v)
            fix(v,values[v],force=true)
			unset_integer(v)
        elseif is_binary(v)
            fix(v,values[v],force=true)
			unset_binary(v)
        end
	end
end

@doc raw"""
	function solve_model()

inputs: EP - a JuMP model representing the energy optimization problem
setup - a Dict containing GenX setup flags

description: Solves and extracts solution variables for later processing

returns: results EP model object with a set of DataFrames containing key results
"""
function solve_model(EP::Model, setup::Dict)
	################################################################################
	## function solve_model()
	##
	## inputs: EP - a JuMP model representing the energy optimization problem
	## setup - a Dict containing GenX setup flags
	##
	## description: Solves and extracts solution variables for later processing
	##
	## returns: results EP model object with a set of DataFrames containing key results
	##
	################################################################################
	## Start solve timer
	solver_start_time = time()
	solver_time = time()

	##Debugging
	if setup["Debug"]==1
		println("Debugging with 'Conflicts' method")
		optimize!(EP)
		compute_conflict!(EP)
		if get_attribute(EP, MOI.ConflictStatus()) == MOI.CONFLICT_FOUND
			iis_model, _ = copy_conflict(EP)
			#open("debug_report.txt", "w") do f
			#	println(f,iis_model)
			#end
		end
		list_of_conflicting_constraints = ConstraintRef[]
		list_of_conflicting_constraints_names = []
		for (F, S) in list_of_constraint_types(EP)
			for con in all_constraints(EP, F, S)
				if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
					push!(list_of_conflicting_constraints, con)
					push!(list_of_conflicting_constraints_names,name(con))
				end
			end
		end
		print(list_of_conflicting_constraints_names)
		print(list_of_conflicting_constraints)
	elseif setup["Debug"]==2
		println("Debugging with 'Penalty' method")
		map = relax_with_penalty!(EP)
		optimize!(EP)
		for (con, penalty) in map
			violation = value(penalty)
			if violation > 0
				open("debug_report.txt", "w") do f
					println("Constraint `$(name(con))` is violated by $violation")
				end
			end
		end
	else
		## Solve Model
		optimize!(EP)
	end




	if has_duals(EP) # fully linear model
		println("LP solved for primal")
	else
		println("MILP solved for primal")
	end

	if !has_duals(EP) && setup["WriteShadowPrices"] == 1
		# function to fix integers and linearize problem
		fix_integers(EP)
		# re-solve statement for LP solution
		println("Solving LP solution for duals")
		optimize!(EP)
	end

	## Record solver time
	solver_time = time() - solver_start_time

	return EP, solver_time
end # END solve_model()
