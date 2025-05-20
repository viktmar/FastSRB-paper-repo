
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DataFrames
using CSV
using FastSRB

function files_to_df(path)
    namess = filter(x -> x != ".DS_Store" && !occursin("_failed", x), readdir(path))
    analysis = map(namess) do name
        df = CSV.read(joinpath(path, name), DataFrame, delim="; ")
        df = df[completecases(df), :]
        found = size(df, 1)
        name, yaml_bench[name]["moniker"], yaml_bench[name]["difficulty"], yaml_bench[name]["accept"][1], found
    end
    df = DataFrame(analysis, [:name, :moniker, :difficulty, :equation, :n_found])
    sort!(df, :n_found, rev=true)
    return df
end

yaml_bench = FastSRB.MAIN_BENCH[]

path_tisr = "2025_03_28_analyzed_merged/tisr"
path_pysr = "2025_03_28_analyzed_merged/pysr"

tisr_analysis_df = files_to_df(path_tisr)
pysr_analysis_df = files_to_df(path_pysr)

# inner join
df = innerjoin(tisr_analysis_df, pysr_analysis_df, on=[:name, :moniker, :difficulty, :equation], makeunique=true, renamecols= "_tisr" => "_pysr")

sort!(df, [:n_found_pysr, :n_found_tisr], rev=true)

CSV.write("results/results_both.csv", df)

