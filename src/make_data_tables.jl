
#### Main wrapper function to make the tables ####

"""
    make_data_tables(;
        input_data::Union{String, DataFrame},
        crossbreaks::Vector{Symbol},
        weight_column::Union{Nothing, Symbol},
        rows::Union{Nothing, Vector{Symbol}} = nothing,
        categorical_methods::Vector{Symbol} = [:population],
        numeric_methods::Vector{Symbol} = [:mean, :sd],
        response_options_to_drop::Vector{String} = ["NotSelected"],
        max_options::Int = 25,
        bonferroni_correction::Bool = true
    ) -> DataFrame

Creates analysis tables from survey data with crossbreaks (subgroups).

# Arguments
- `input_data`: Survey data in DataFrame format, or string pointing to .csv or .sav file
- `crossbreaks`: Variables to use for subgroup analysis
- `weight_column`: Column containing survey weights
- `rows`: Variables to analyze (default value of nothing means do all columns)
- `categorical_methods`: Statistics to calculate for categorical variables (e.g., [:population_pct, :n, :sigtest])
- `numeric_methods`: Statistics to calculate for numeric variables (e.g., [:mean, :sd, :median])
- `response_options_to_drop`: Response values to exclude from results (e.g., "NotSelected")
- `max_options`: Skip variables with more than this many unique values
- `bonferroni_correction`: Reduce the p-threshold on significance tests by the number of comparisons to avoid false positives

See readme for a full list of available methods.

# Returns
DataFrame with analysis results organized by variable, response option, and statistic.
Includes rebased percentages across subgroups for easy comparison.

Question labels will be extracted from an .sav if passed in as a string, otherwise column names are used.

# Example
```julia
results = make_data_tables(;
    input_data = survey_df,
    crossbreaks = [:gender, :age_group],
    weight_column = :weight
)
```
"""
function make_data_tables(;
        input_data::Union{String, DataFrame},
        crossbreaks::Vector{Symbol},
        weight_column::Union{Nothing, Symbol},
        rows::Union{Nothing, Vector{Symbol}} = nothing,
        categorical_methods::Vector{Symbol} = [:population_pct],
        numeric_methods::Vector{Symbol} = [:mean, :sd],
        response_options_to_drop::Vector{String} = ["NotSelected"],
        max_options::Int = 25,
        bonferroni_correction::Bool=true
    )

    #Read input data if not already, and get labels
    if input_data isa String
        data_labels, input_data = read_data(input_data)
    else 
        data_labels = names(input_data)
    end
    data_labels_dict = Dict(zip(propertynames(input_data), data_labels))

    #Make default weight if nothing passed
    if isnothing(weight_column)
        weight_column = :weight
        input_data.weight .= 1.0
    end

    ## Get vector of variables to drop

    #make dataframe
    nunique_info = describe(input_data, :eltype, :nunique)

    # Identify strings and labeled values with too many unique values
    too_many_categories = ((nunique_info.eltype .<: AbstractString) .| (nunique_info.eltype .<: LabeledValue)) .&
                        (something.(nunique_info.nunique, 0) .>= max_options)

    if sum(too_many_categories) > 0
	    @warn "Excluding the following variables for exceeding max_options:\n$(nunique_info[too_many_categories, [:variable, :nunique]])"
    end

    # Identify non-numeric, non-string, non-labeled types
    other_types = .!((nunique_info.eltype .<: Union{Missing, Number}) .| 
                    (nunique_info.eltype .<: Union{Missing, AbstractString}) .| 
                    (nunique_info.eltype .<: LabeledValue))

    if sum(other_types) > 0
        @warn "Excluding the following variables for having a type not number or categorical:\n$(nunique_info[other_types,[:variable, :eltype]])"
    end

    # Combine criteria for exclusion
    exclude_vars = nunique_info.variable[too_many_categories .| other_types]


    #Get default rows if nothing passed
    if isnothing(rows)
        rows = setdiff(
            propertynames(input_data), 
            [:respondent_id, weight_column, exclude_vars...]
        )
    end

    #Drop rows if weight is missing
    if any(ismissing, input_data[!,weight_column])
        missing_weights = ismissing.(input_data[!, weight_column])
        @warn ("Dropping $(sum(missing_weights)) rows because of missing weights.")
        input_data = input_data[.!missing_weights,:]
    end

    #assign weight
    weights = convert(Vector{Float64}, input_data[!,weight_column])

    #create the crossbreak object
    crossbreak = CrossBreak(input_data, crossbreaks)

    #Calculate tables
    @info "Calculating tables..."
    tables = Vector{DataFrame}()

    ## Make the 'tables' for population and sample n 
    all_row = RowVariable(fill("all", length(weights)), "Whole Sample", weights)
    for method in [:n, :population]
        all_table = calculate_row(all_row, crossbreak, method; sigtest_correction=bonferroni_correction)
        push!(tables, all_table)
    end
    
    ## if required, make the 'table' for column names
    if :sigtest in numeric_methods || :sigtest in categorical_methods
        sigtest_letters = string.(['A' + i - 1 for v in values(crossbreak.breaks) for i in 1:length(v)])
        #NB not secure column name matching, see calculate.jl
        sigtest_row_values = [
            "", #Total column
            "Column Letters", #Row labels
            0, #Variable N
            "Column Comparison", #Row variable
            "sigtest", #Statistic
            sigtest_letters...,
            ]
        sigtest_table = DataFrame(permutedims(sigtest_row_values), names(first(tables))) #pull column names from the ones we've already done
        push!(tables, sigtest_table)
    end

    #Load data storage for auto NETs
    autoNETs_path = joinpath(@__DIR__, "..", "data", "auto_NETs.toml")
    autoNETs::Dict{String, Dict{String, String}} = TOML.parsefile(autoNETs_path)

    ##Loop over rows

    for row_var in ProgressBar(rows)

        #Skip if  over max vars
        if row_var in exclude_vars
            @warn "Variable $var has more than the specified maximum $max_options categories - skipping."
            continue
        end

        #Init variable info object using dataframe constructor
        row_table = RowVariable(input_data, row_var, get(data_labels_dict, row_var, string(row_var)), weights)

        #Check variable type
        if typeof(row_table) <: RowVariable{Union{Missing, String}}

            for method in categorical_methods
                #Calculate table and append to list, once for each method
                row_df = calculate_row(row_table, crossbreak, method; sigtest_correction=bonferroni_correction)
                push!(tables, row_df)
                
                ### Auto NETs handled here, categorical only ###

                #Search over dictonary for matches
                for NET_dict in values(autoNETs) 

                    if all(in(row_table.row_labels), keys(NET_dict))

                        #if so, make new values and name, and define the order
                        new_values = get.(Ref(NET_dict), row_table.row_values, "NET_Other")
                        new_name = "$(row_table.row_var)_NET"
                        value_order = [unique(values(NET_dict))..., "NET_Other"]
                        #like this so it doesn't break if there's no NET_other
                        intersect!(value_order, unique(new_values))

                        #Use other RowVariable constructor
                        NET_rowtable = RowVariable(new_values, new_name, row_table.weight; order = value_order)

                        #Calculate the table and append
                        row_df = calculate_row(NET_rowtable, crossbreak, method; sigtest_correction=bonferroni_correction)

                        push!(tables, row_df)

                        break #Only one auto NET per variable
                    end
                end

                ### End Auto NET logic ###
            end

        elseif typeof(row_table) <: RowVariable{Union{Missing, Float64}}

            for method in numeric_methods
                row_df = calculate_row(row_table, crossbreak, method; sigtest_correction=bonferroni_correction)
                push!(tables, row_df)
            end

        else
            @warn "Could not calculate table for type $(typeof(row_table)) for column $row_var"
        end
    end

    @info "Processing tables..."

    #Concatenate tables
    all_tables = vcat(tables...)

    #Filter out rows to drop
    filter!(row -> .!in.(row._ROWLABELS, Ref(response_options_to_drop)), all_tables)

    #Reorder columns
    label_cols = ["_ROWVARIABLE", "_ROWLABELS", "_VARIABLE_N", "_STATISTIC"]
    select!(all_tables, label_cols, Not(label_cols))

    ##Sort, efficiently

    #Make orders of how to sort statistics
    stat_order = Dict(
        "population_pct" => 1, "n_pct" => 2, "mean" => 3, "sd" => 4, "median" => 5,
        "iqr" => 6, "population" => 6, "n" => 7, "sigtest" => 8
    )
    
    # Pre-compute all sort keys directly as table columns
    all_tables.sort_key1 = indexin(all_tables._ROWVARIABLE, unique(all_tables._ROWVARIABLE))
    all_tables.sort_key2 = indexin(all_tables._ROWLABELS, unique(all_tables._ROWLABELS))
    all_tables.sort_key3 = [stat_order[x] for x in all_tables._STATISTIC]
    
    # Sort once using these pre-computed keys
    sort!(all_tables, [:sort_key1, :sort_key2, :sort_key3])
    
    # Remove the temporary columns
    select!(all_tables, Not([:sort_key1, :sort_key2, :sort_key3]))
    
    ## End efficient sort logic

    #Make rebased section
    cols_to_rebase = setdiff(names(all_tables), [label_cols..., "Total"])

    for col in cols_to_rebase
        newname = "$(col) (REBASED)"
        #Get ids where sigtest is not in the table
        idx = all_tables[!,:_STATISTIC] .!= "sigtest"
        try
            #calculate ignoring sigtest rows
            col_rebased_raw = all_tables[idx,col] ./ all_tables[idx,:Total] .* 100
            col_rebased = ifelse.(isnan.(col_rebased_raw), missing, col_rebased_raw)
            col_rebased = round.(Union{Int64, Missing}, col_rebased)
            #reassemble column of correct type
            new_col = Vector{Union{Int64, Missing}}(missing, size(all_tables, 1))
            new_col[idx] = col_rebased
            #add back into dataframe
            all_tables[!,newname] = new_col
        catch e 
            @warn "Could not rebase column $col:" e
        end
    end

    #Rename
    rename!(all_tables, 
        :_ROWVARIABLE => :Variable,
        :_ROWLABELS => Symbol("Response Option"),
        :_VARIABLE_N => Symbol("Variable n"),
        :_STATISTIC => :Statistic,
        )

    return all_tables
end

export make_data_tables
