
#Function to read data

function read_data(filepath::String)
    _, ext = splitext(filepath)

    if ext == ".sav"
        return DataFrame(readstat(filepath))
    elseif ext == ".csv"
        return DataFrame(CSV.File(filepath))
    else
        error("Data must be .csv or .sav format")
    end
end
