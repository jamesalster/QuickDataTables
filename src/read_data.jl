
"""
Reads data from a file.

Arguments:
- `filepath`: {String} - Path to the data file in `.csv` or `.sav` format.

Returns:
- A tuple containing an array of unique identifier labels (`Vector{String}`) and 
  a dataframe (`DataFrame`) with corresponding data variables, including column names.
- Throws:
    - {Error}: Data file is not recognized by the function (must be `.csv` or `.sav`)
"""
function read_data(filepath::String)::Tuple{Vector{String},DataFrame}
    _, ext = splitext(basename(filepath))

    if ext in [".sav", ".dta", ".sas7bdat", ".xpt"]
        stat_table = readstat(filepath)
        df = DataFrame(stat_table)
        #Get column labels
        data_labels = colmetavalues(stat_table, :label)
        data_labels = ifelse.(data_labels .== "", names(df), data_labels)
    elseif ext == ".csv"
        df = DataFrame(CSV.File(filepath))
        data_labels = names(df)
    else
        error("Data must be .csv, .sav, .dta, .sas7bdat or .xpt format")
    end

    return data_labels, df
end
