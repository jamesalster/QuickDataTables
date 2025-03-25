
#### Crossbreak object, holding crossbreak information

#Dict of colnames, each a dict of col values and then indices in the df
struct CrossBreak
    breaks::OrderedDict{Symbol, OrderedDict{Symbol, BitVector}}
end

#Helper function
function index_as_bitvector(search_strings::Vector{String}, all_strings::Vector{String})
    OrderedDict(Symbol(str) => (all_strings .== str) for str in search_strings)
end

#Outer constructor, processing SPSS info
function CrossBreak(df::DataFrame, break_vars::Vector{Symbol})
    
    breaks = OrderedDict{Symbol, OrderedDict{Symbol, Vector{Int}}}()

    for var in break_vars
        col = df[!,var]
        if eltype(col) <: LabeledValue
            #SPSS order of levels
            break_levels = string.(values(sort(getvaluelabels(col))))
            println(break_levels)
            #get indices as dict
            break_indices = index_as_bitvector(break_levels, string.(collect(valuelabels(col))))
            #assign to dict
            breaks[var] = break_indices
        else #Alphabetical order
            break_levels[var] = sort(unique(col))
            break_indices = index_as_bitvector(break_levels, col)
            breaks[var] = break_indices
        end
    end

    return CrossBreak(breaks)
end