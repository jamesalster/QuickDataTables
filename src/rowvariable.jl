
#### Object to hold row variable information

struct RowVariable{T} #T is the type
    size::Int
    valid_cases::Int
    row_var::Symbol
    row_values::Vector
    row_labels::Vector{AbstractString}
    row_label::String
    weight::Vector{Float64}
end


#Table constructor - this is where we define table properties (in terms of the row)
function RowVariable(df::DataFrame, row_var::Symbol, row_label::String, weights::Vector{Float64})::RowVariable
    row_values = df[!,row_var]

    if eltype(row_values) <: Union{Number, Missing}
        row_labels = [string(row_var)]
        row_values = convert(Vector{Union{Float64, Missing}}, row_values)
    #Handle SPSS here
    elseif eltype(row_values) <: Union{LabeledValue, Missing}
        #In-order vector (getvaluelabels returns Dict of value => label)
        row_labels = string.(values(sort(getvaluelabels(row_values))))
        row_values = collect(valuelabels(row_values))
    else
        #Alphabetical for normal strings
        row_labels = sort(unique(row_values))
    end

    #Define 'type' of the variable
    type = Union{eltype(row_values), Missing}

    return RowVariable{type}(
        length(row_values),
        length(row_values) - sum(ismissing.(row_values)),
        row_var,
        row_values,
        row_labels,
        row_label,
        weights,
    )
end

#Constructor passing the vector of strings directly, with their order
function RowVariable(
        row_values::Vector, 
        row_label::String, 
        weights::Vector{Float64};
        order::Vector{String} = sort(unique(row_values))
    )::RowVariable

    #Define 'type' of the variable
    type = Union{eltype(row_values), Missing}

    return RowVariable{type}(
        length(row_values),
        length(row_values) - sum(ismissing.(row_values)),
        Symbol(row_label),
        row_values,
        order,
        row_label,
        weights,
    )
end