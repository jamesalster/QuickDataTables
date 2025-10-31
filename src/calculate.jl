
### Main table calculation functions ####

### Main table caluclation function

function calculate_single_break(
        t::RowVariable{T}, 
        crossbreak::Pair{Symbol, OrderedDict{Symbol, BitVector}}, 
        method::Symbol; #population, n, population_pct, n_pct, sigtest
        no_breaks::Bool = false,
        sigtest_correction::Bool = true
    )::DataFrame where T

    break_name = first(crossbreak)
    break_dict = last(crossbreak)

    #Init dataframe
    out_df = DataFrame()
    
    #Get non-missing values
    valid_mask = .!ismissing.(t.row_values)

    #Ignore breaks if we want to
    if no_breaks
        break_dict = OrderedDict(:Total => trues(t.size))
    end

    #For each level, make an empty column
    for lvl in keys(break_dict)
        lvlcol = zeros(length(t.row_labels))

        break_idx = break_dict[lvl] .& valid_mask

        #work out which indices are relevant and sum the weights
        for i in eachindex(lvlcol) #for rows in table
            #Logic for type of element and also method as passed
            if T <: Union{String, Missing}
                idx = (t.row_values .== t.row_labels[i]) .& break_idx 

                if method === :population || method === :population_pct
                    lvlcol[i] = sum(t.weight[idx])
                elseif method === :n || method === :n_pct || method === :sigtest
                    lvlcol[i] = sum(idx)
                else
                    error("Method $method not implemented for categorical table")
                end

            elseif T <: Union{Number, Missing}
                idx = break_idx 
                non_missing_values = convert(Vector{Float64}, t.row_values[idx])
                if method === :mean
                    lvlcol[i] = mean(non_missing_values, Weights(t.weight[idx]))
                elseif method === :median
                    lvlcol[i] = median(non_missing_values, Weights(t.weight[idx]))
                elseif method === :sd
                    lvlcol[i] = std(non_missing_values, Weights(t.weight[idx]))
                elseif method === :iqr
                    lvlcol[i] = iqr(non_missing_values)
                elseif method === :n
                    lvlcol[i] = sum(idx)
                elseif method === :sigtest
                    #Will have to be done with raw vectors
                    error("Numeric Sigtest flow is different, should not reach this point.")
                else 
                    error("Method $method not implemented for numeric table")
                end

            else
                error("No table method for type $(string(T)) implemented")
            end
            
        end

        #Pct if necessary
        if method === :population_pct || method === :n_pct
            lvlcol = lvlcol ./ sum(lvlcol)
        end

        #assign into df
        if no_breaks
            colname = "Total"
        else
            colname = "$(break_name): $(lvl)"
        end

        out_df[!,colname] = lvlcol

    end

    #Sigtest the df if necessary
    if method === :sigtest
        out_df = get_sig_differences_categorical(out_df; correction=sigtest_correction)
    end

    #Add the other columns we need
    out_df[!,:_ROWLABELS] = t.row_labels
    out_df[!,:_VARIABLE_N] .= t.valid_cases
    out_df[!,:_ROWVARIABLE] .= string(t.row_label)
    out_df[!,:_STATISTIC] .= string(method)

    return out_df               
end

### Calculate a whole row table
function calculate_row(
        t::RowVariable{T}, 
        crossbreak::CrossBreak, 
        method::Symbol;
        sigtest_correction::Bool=true)::DataFrame where T

    single_breaks = Vector{DataFrame}()

    #Iterate over breaks, making each

    #First, do Total column 
    if T <: Union{Number, Missing} && method === :sigtest #special numeric sigtest handling
        total_col = calculate_break_numeric_sigtest(t, first(crossbreak.breaks); no_breaks = true, sigtest_correction=sigtest_correction)
    else
        #doesn't matter which crossbreak we pass
        total_col = calculate_single_break(t, first(crossbreak.breaks), method; no_breaks = true, sigtest_correction=sigtest_correction)
    end

    push!(single_breaks, total_col)

    #Then, do all the others

    #Loop over making single break tables
    for break_dict in crossbreak.breaks
        if T <: Union{Number, Missing} && method === :sigtest
            tab = calculate_break_numeric_sigtest(t, break_dict; sigtest_correction=sigtest_correction)
        else
            tab = calculate_single_break(t, break_dict, method; sigtest_correction=sigtest_correction)
        end
        push!(single_breaks, tab)
    end

    #Join, there should be no missing
    joined_table = reduce((x, y) -> outerjoin(x, y, on = [:_ROWVARIABLE, :_ROWLABELS, :_VARIABLE_N, :_STATISTIC]), single_breaks)
    try
        disallowmissing!(joined_table)
    catch e
        @warn "Missing values in table: " e
    end

    return joined_table
end

##### Special numeric sigtest calculation function
#For efficiency, the table is assembled by row in this case 
#(iterating over crossbreak) rather than by column 
#(since there's only one row for numeric variables)
#Logic v different to main calculate row function

function calculate_break_numeric_sigtest(
        t::RowVariable, 
        crossbreak::Pair{Symbol, OrderedDict{Symbol, BitVector}}; 
        no_breaks::Bool = false,
        sigtest_correction::Bool = true
    )::DataFrame

    break_name = first(crossbreak)
    break_dict = last(crossbreak)

    #Get non-missing values
    valid_mask = .!ismissing.(t.row_values)

    #Ignore breaks if asked
    if no_breaks
        out_df = DataFrame(permutedims([" "]), ["Total"])
    #Otherwise calculate sig test
    else
        #Make a dictionary of relevant samples for each level
        lvl_values = Vector{Vector{Float64}}()
        colnames = Vector{String}()
        for lvl in keys(break_dict)
            break_idx = break_dict[lvl] .& valid_mask
            push!(lvl_values, t.row_values[break_idx])
            push!(colnames, "$(break_name): $(lvl)")
        end

        sigtest_results = get_sig_differences_numeric(lvl_values; correction=sigtest_correction)
        out_df = DataFrame(permutedims(sigtest_results), colnames)
    end

    #Add the other columns we need for joining
    out_df[!,:_ROWLABELS] = t.row_labels
    out_df[!,:_VARIABLE_N] .= t.valid_cases
    out_df[!,:_ROWVARIABLE] .= string(t.row_label)
    out_df[!,:_STATISTIC] .= "sigtest"

    return out_df
end

###

export calculate_row
