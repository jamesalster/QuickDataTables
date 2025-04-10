
#### Functions to calculate significant differences

using HypothesisTests

function get_sig_differences_categorical(df::DataFrame)

    #Iterate over dataframe rows
    in_array = Matrix(df)
    out_array = Matrix{String}(undef, size(in_array))

    rows, cols = size(in_array)

    #If one col, we cant sigtest
    if cols == 1
        out_array .= " "
        return DataFrame(out_array, ["Total"])
    end

    #Values for test must be Integer  
    try
        in_array = Int.(in_array)
    catch
        @warn "Could not sigtest for array, could not convert to integer"
        out_array .= " "
        return DataFrame(out_array, names(df))
    end

    for i in 1:rows

        #Init vector
        sig_differences = [Vector{Char}() for i in 1:cols]

        row_values = view(in_array, i, :)

        #Loop over values and add in letters where significance deteceted
        for i in eachindex(row_values)
            for j in i:length(row_values) #upper triangle only

                #Get pair of values to test
                test_pair = view(row_values, [i,j])

                #Check no values are 0, if so, can't test
                if all(test_pair .> 0)

                    #Run test
                    pval = pvalue(ChisqTest(test_pair))

                    #Record result
                    if pval < 0.01
                        push!(sig_differences[j], 'A' + i - 1)
                        push!(sig_differences[i], 'A' + j - 1)
                    elseif pval < 0.05
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

