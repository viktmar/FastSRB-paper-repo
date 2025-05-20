
# Fast Symbolic Regression Benchmarking

This repository accompanies the [Fast Symbolic Regression Benchmarking]() publication.
It's designed to allow repeating the conducted experiments.
The implementation of the benchmark itself can be found [here](https://github.com/viktmar/FastSRB).

To run this benchmark, clone this repository, install GNU parallel & Julia 1.11+, and run the following command in the root of the repository folder:

```
parallel --color --bar --timeout 10000 -j8 --joblog results/joblogfile.txt -a src/jobs.txt
```
(please adapt `-j8` to the number of physical processors available on your machine)

This command will run 240 (2 packages x 120 problems) [jobs](src/jobs.txt) with at most eight running in parallel.
Each job runs either [this](src/pysr.jl) or [that](src/tisr.jl) file using Julia, and repeats a benchmark problem five times.
For each job, an output file is created [here](results/pysr/) or [there](results/tisr/) to record successful runs.
In case of potential new acceptable expressions, a separate file is created, which must be analyzed in the post-processing.

To post-process, go through each of the output files ending in "_failed".
If there is a functionally equivalent expression for a run, which did not terminate successfully, manually add the new expression to the output file.
Also, you may create a pull request or an issue in the [FastSRB](https://github.com/viktmar/FastSRB) repository to add new acceptable expressions.

