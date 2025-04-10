
module QuickDataTables

    using StatsBase
    using DataFrames
    using ReadStatTables
    using CSV
    using DataStructures
    using TOML
    using ProgressBars
    using HypothesisTests


    include("read_data.jl")
    include("crossbreak.jl")
    include("rowvariable.jl")
    include("sigtests.jl")
    include("calculate.jl")
    include("make_data_tables.jl")

    export read_data, make_data_tables

end