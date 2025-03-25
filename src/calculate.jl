
### Main table calculation functions ####

### Main table calucaltion function

function calculate_single_break(
        t::RowVariable{T}, 
        crossbreak::Pair{Symbol, OrderedDict{Symbol, BitVector}}, 
        method::Symbol; #population, n, population_pct, n_pct, sigtest
        no_breaks::Bool = false
    )::DataFrame where T

    break_name = first(crossbreak)
    break_dict = last(crossbreak)

    out_df = DataFrame()
    out_df[!,:_ROWLABELS] = t.row_labels
    out_df[!,:_ROWVARIABLE] .= string(t.row_label)
    out_df[!,:_STATISTIC] .= string(method)

    valid_mask = .!ismissing.(t.row_values)

    #Ignore breaks if we want to
    if no_breaks
        break_dict = OrderedDict(:Total => trues(t.size))
    end

    #For each level, make an empty column
    for lvl in keys(break_dict)
        lvlcol = zeros(size(out_df, 1))

        break_idx = break_dict[lvl] .& valid_mask

        #work out which indices are relevant and sum the weights
        for i in eachindex(lvlcol) #for rows in table
            #Logic for type of element and also method as passed
            if T <: String
                idx = (t.row_values .== t.row_labels[i]) .& break_idx 

                if method === :population || method === :population_pct
                    lvlcol[i] = sum(t.weight[idx])
                elseif method === :n || method === :n_pct
                    lvlcol[i] = sum(idx)
                elseif method === :sigtest
                    #Will have to be done below with pct
                    error("Sigtest method not implemented")
                else
                    error("Method $method not implemented for categorical table")
                end

            elseif T <: Number
                idx = break_idx 
                if method === :mean
                    levelcol[i] = mean(t.row_values[idx], Weights(t.weight[idx]))
                elseif method === :median
                    levelcol[i] = median(t.row_values[idx], Weights(t.weight[idx]))
                elseif method === :sd
                    levelcol[i] = std(t.row_values[idx], Weights(t.weight[idx]))
                elseif method === :n
                    levelcol[i] = sum(idx)
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

    return out_df               
end

### Calculate a whole row table
function calculate_row(t::RowVariable, crossbreak::CrossBreak, method::Symbol)::DataFrame

    single_breaks = Vector{DataFrame}()

    #Total column - doesn't matter which crossbreak we pass
    total_col = calculate_single_break(t, first(crossbreak.breaks), method; no_breaks = true)
    push!(single_breaks, total_col)

    #Loop over making single break tables
    for break_dict in crossbreak.breaks
        tab = calculate_single_break(t, break_dict, method)
        push!(single_breaks, tab)
    end

    #Join, there should be no missing
    joined_table = reduce((x, y) -> outerjoin(x, y, on = [:_ROWVARIABLE, :_ROWLABELS, :_STATISTIC]), single_breaks)
    try
        disallowmissing!(joined_table)
    catch e
        @warn "Missing values in table: " e
    end

    return joined_table
end

export calculate_row