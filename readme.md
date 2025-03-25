
# QuickDataTables

Julia package for making quick local data tables. 

## Usage

The main exported function is **make_data_tables()**, which takes many arguments, and returns (for now) a *DataFrame*. 

**read_data()** is also exported, reading a .sav or .csv file, for convenience.

##  Arguments to make_data_tables()

- `input_data`: Survey data in DataFrame format, or string pointing to .csv or .sav file
- `crossbreaks`: Variables to use for subgroup analysis
- `weight_column`: Column containing survey weights
- `rows`: Variables to analyze (default value of nothing means do all columns)
- `categorical_methods`: Statistics to calculate for categorical variables (e.g., [:population])
- `numeric_methods`: Statistics to calculate for numeric variables (e.g., [:mean, :sd])
- `response_options_to_drop`: Response values to exclude from results (e.g., "NotSelected")
- `max_options`: Skip variables with more than this many unique values
- `pct_for_categorical`: When true, shows categorical data as percentages

## Methods

These are the methods available to be passed to the `categorical_methods` and `numeric_methods` fields. Multiple methods can be passed and multiple rows will be returned.

* **Categorical Methods**:
    * `:population`: the sum of the weights
    * `:n`: the number of cases
    * `:population_pct` (default): the weighted %, by column
    * `:n_pct`: the raw %, by column
    * `:sigtest`: significance testing
* **Numeric Methods**:
    * `:mean`: the weighted mean
    * `:median`: the weighted median
    * `:sd`: the weighted standard deviation
    * `:n`: the number of cases

## Brief Example

```julia
using QuickDataTables
using CSV

filepath = "some_file.csv"

tables = make_data_tables(;
    input_data = filepath,
    crossbreaks = [:A1, :A2, :A3],
    weight_column = :weight
)

CSV.write("example_tables.csv", tables)
```

## Src/

The internal functionality is broken down as follows:

* **crossbreak.jl**: defines a CrossBreak object containing information about the required crossbreaks. This is really a nested Dict, but has its own struct for extensibility (with e.g. custom labels) in future
* **rowvariable.jl**: defines a RowVariable object containing information about the variable in each 'row' of the datatables. This processes the .sav labels and stores their order
* **calculate.jl**: two functions, where the calculations take place.
    * *calculate_row()* : takes a RowVariable and CrossBreak and  method, calculates the individual tables by iterating through the crossbreak calling *calcuate_single_break()*, and then joins them together
    * *calculate_single_break()* : takes a RowVariable, method and single part of the crossbreak and actually performs the relevant calculation.
* **make_data_tables.jl**: the main wrapper function. This takes all the info required, and calculates the tables iterating over the rows with *calculate_row()*, specifiying the apprioriate methods and formatting the final output.
* **read_data.jl**: a simple convenience function for reading .csv or .sav files as a dataframe. Could add other filetypes in here.


## To-do

* add SAV questions to output
* add significance testing
* auto NETs
* consider excel formatting (long term)