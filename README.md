
This repository accompanies the [Fast Symbolic Regression Benchmarking]() publication.
It's designed to allow repeat the conducted experiments.
The implementation of the benchmark itself can be found [here](https://github.com/viktmar/FastSRB/tree/0.1.0-beta).

To run this benchmark, clone this repository, install GNU parallel & Julia 1.11+, and run the following command:

```
parallel --color --bar --timeout 10000 -j8 --joblog results/joblogfile.txt -a src/jobs.txt
```
(please adapt `-j8` to the number of physical processors available on your machine)

This command will run 240 (2 packages x 120 problems) [jobs](src/jobs.txt) with at most eight running in parallel.
Each job runs either [this](src/pysr.jl) or [that](src/tisr.jl) file using Julia, and repeats a benchmark problem five times.
For each job, an output file is created [here](results/pysr/) or [there](results/tisr/), where successful runs are recorded.
In case of potential new acceptable expressions, a separate file is created, which must be analyzed in the post-processing.


