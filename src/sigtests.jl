
#### Functions to calculate significant differences

#Takes a dataframe
#Iterates over rows of integers and turns them into the letter comparisons
#Returns a dataframe
#Needs whole dataframe so it knows population totals

function get_sig_differences_categorical(df::DataFrame; correction::Bool=true)::DataFrame

    #Iterate over dataframe rows
    in_array = Matrix(df)
    out_array = Matrix{String}(undef, size(in_array))

    rows, cols = size(in_array)


    #If one col, or less than 30 indivs total, we can't/shouldn't sigtest
    if cols == 1 
        out_array .= " "
        return DataFrame(out_array, ["Total"])
    elseif sum(in_array) < 30
        out_array .= " "
        return DataFrame(out_array, names(df))
    end

    #Values for test must be Integer  
    try
        in_array = Int.(in_array)
    catch
        @warn "Could not sigtest for array, could not convert to integer"
        out_array .= " "
        return DataFrame(out_array, names(df))
    end

    #Get population sizes
    pop_sizes = dropdims(sum(in_array; dims = 1); dims = 1)

    for i in 1:rows

        #Init vector
        sig_differences = [Vector{Char}() for _ in 1:cols]

        row_values = view(in_array, i, :)

        #Loop over values and add in letters where significance deteceted
        for i in eachindex(row_values)
            for j in i:length(row_values) #upper triangle only

                # check we have enough sample to test
                if (pop_sizes[i] + pop_sizes[j]) >= 30

                    #Chisq - no longer used
                    #Get contingency table
                    #contingency_table = [
                    #    row_values[i] row_values[j];
                    #    pop_sizes[i]-row_values[i] pop_sizes[j]-row_values[j]
                    #]

                    #Run test
                    #pval = pvalue(ChisqTest(contingency_table))
                    pval = twopropztest(row_values[i], pop_sizes[i], row_values[j], pop_sizes[j])

                    # Record result
                    # Bonferroni correction
                    comparisons = correction ? cols * (cols-1) / 2 : 1
                    #comparisons = 1
                    if pval < (0.01 / comparisons)
                        push!(sig_differences[i], 'A' + j - 1)
                        push!(sig_differences[j], 'A' + i - 1)
                    elseif pval < (0.05 / comparisons)
                        push!(sig_differences[j], 'a' + i - 1)
                        push!(sig_differences[i], 'a' + j - 1)
                    end
                end
            end
        end

        #Combine into cell values
        out_array[i,:] = [join(diffs, " ") for diffs in sig_differences]
    end

    #Convert to dataframe
    out_df = DataFrame(out_array, names(df))
    return out_df
end

#### Takes a vector of numeric vectors, representing the values to be compared
#### Returns a vector of string comparisons
#### These are assembled back into the dataframe in calculate.jl in calculate_break_numeric_sigtest() 

function get_sig_differences_numeric(row_values::Vector{Vector{Float64}}; correction::Bool=true)::Vector{String}

    #Iterate over dataframe rows
    out_array = Vector{String}(undef, length(row_values))

    cols = length(row_values) 

    #If one col or less than 30 obs, we can't / shouldn't sigtest
    if (cols == 1) || (sum(length.(row_values)) < 30)
        out_array .= " "
        return out_array
    end

    #Init vector
    sig_differences = [Vector{Char}() for i in 1:cols]

    #Loop over values and add in letters where significance deteceted
    for i in eachindex(row_values)
        for j in i:length(row_values) #upper triangle only

            #Run test
            pval = pvalue(ApproximateMannWhitneyUTest(row_values[i],row_values[j]))

            # Record result
            # Bonferroni correction
            comparisons = correction ? cols * (cols-1) / 2 : 1
            if pval < (0.01 / comparisons)
                push!(sig_differences[j], 'A' + i - 1)
                push!(sig_differences[i], 'A' + j - 1)
            elseif pval < (0.05 / comparisons)
                push!(sig_differences[j], 'a' + i - 1)
                push!(sig_differences[i], 'a' + j - 1)
            end
        end

        #Combine into cell values
        out_array = [join(diffs, " ") for diffs in sig_differences]
    end

    return out_array
end

