
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
        max_options::Int = 25
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
        max_options::Int = 25
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

    #Get vector of variables to drop
    nunique_info = describe(input_data, :nunique)
    exclude_vars = nunique_info.variable[something.(nunique_info.nunique, 0) .>= max_options]

    #Get default rows if nothing passed
    if isnothing(rows)
        rows = setdiff(
            propertynames(input_data), 
            [:respondent_id, weight_column, exclude_vars...]
        )
    end

    #Define weight
    weights = input_data[!,weight_column]

    #Check no missing weights
    if any(ismissing, weights)
        error("Missing weights are not supported, all cases must be valid")
    end

    crossbreak = CrossBreak(input_data, crossbreaks)

    #Calculate tables
    @info "Calculating tables..."
    tables = Vector{DataFrame}()

    ## Make the 'tables' for population and sample n 
    all_row = RowVariable(fill("all", length(weights)), "Whole Sample", weights)
    for method in [:n, :population]
        all_table = calculate_row(all_row, crossbreak, method)
        push!(tables, all_table)
    end

    ##Loop over rows

    for row_var in rows

        #Skip if  over max vars
        if row_var in exclude_vars
            @warn "Variable $var has more than the specified maximum $max_options categories - skipping."
            continue
        end

        #Init variable info object using dataframe constructor
        row_table = RowVariable(input_data, row_var, get(data_labels_dict, row_var, string(row_var)), weights)

        #Check variable type
        if typeof(row_table) <: RowVariable{String}

            for method in categorical_methods
                #Calculate table and append to list, once for each method
                row_df = calculate_row(row_table, crossbreak, method)
                push!(tables, row_df)
                
                ### Auto NETs handled here, categorical only###

                #Load data storage for them
                autoNETs_path = joinpath(@__DIR__, "..", "data", "auto_NETs.toml")
                autoNETs::Dict{String, Dict{String, String}} = TOML.parsefile(autoNETs_path)

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
                        row_df = calculate_row(NET_rowtable, crossbreak, method)
                        push!(tables, row_df)

                        break #Only one auto NET per variable
                    end
                end

                ### End Auto NET logic ###
            end

        elseif typeof(row_table) <: RowVariable{Number}

            for method in numeric_methods
                row_df = calculate_row(row_table, crossbreak, method)
                push!(tables, row_df)
            end

        else
            @warn "Could not calculate table for type $(typeof(row_table)) for column $row_var"
        end
    end

    #Concatenate tables
    all_tables = vcat(tables...)

    #Filter out rows to drop
    filter!(row -> .!in.(row._ROWLABELS, Ref(response_options_to_drop)), all_tables)

    #Reorder columns
    select!(all_tables, "_ROWVARIABLE", Not("_ROWVARIABLE"))

    #Sort rows using these orders (neat trick)
    sort!(all_tables, [:_ROWVARIABLE, :_ROWLABELS, :_STATISTIC], 
        by = [x -> findfirst(==(x), unique(all_tables._ROWVARIABLE)), 
                x -> findfirst(==(x), unique(all_tables._ROWLABELS)), 
                x -> findfirst(==(x), ["population_pct", "n_pct",  "mean", "median", "sd", "population", "n", "sigtest"])]
            )

    #Make rebased section
    cols_to_rebase = setdiff(names(all_tables), ["_ROWVARIABLE", "_ROWLABELS", "_STATISTIC", "Total"])

    for col in cols_to_rebase
        newname = "$(col) (REBASED)"
        try
            col_rebased_raw = all_tables[!,col] ./ all_tables[!,:Total] .* 100
            col_rebased = ifelse.(isnan.(col_rebased_raw), missing, col_rebased_raw)
            col_rebased = round.(Union{Int64, Missing}, col_rebased)
            all_tables[!,newname] = col_rebased
        catch e 
            @warn "Could not rebase column $col:" e
        end
    end

    #Rename
    rename!(all_tables, 
        :_ROWVARIABLE => :Variable,
        :_ROWLABELS => Symbol("Response Option"),
        :_STATISTIC => :Statistic,
        )

    return all_tables
end

export make_data_tables