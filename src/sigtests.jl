
#### Functions to calculate significant differences

using HypothesisTests

function get_sig_differences_categorical(x::Vector{Int})

    #Init vector
    sig_differences = [Vector{Char}() for i in eachindex(x)]

    #Loop over values and add in letters where significance deteceted
    for i in eachindex(x)
        for j in i:length(x) #upper triangle only

            #Sig test appropriately, can't run if x is 0
            if eltype(x) <: Int && all(x .> 0)
                pval = pvalue(ChisqTest(x[[i,j]]))

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

    return [join(diffs, " ") for diffs in sig_differences]
end

