
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DataFrames
using SymPy
using SymbolicUtils

using TiSR

using FastSRB

# which benchmark problem to run # -----------------------------------------------------------------
name = ARGS[1]

# benchmark settings # -----------------------------------------------------------------------------
out_dir_path = "results/tisr/"

n_runs            = 5
t_lim             = 60.0 * 30.0
n_points          = 400
train_test        = 0.5

search_compl_incr = 1.5
accept_compl_incr = 1.2

accept_max_are_test    = 1e-8
accept_param_sigdigits = 5

# custom functions # -------------------------------------------------------------------------------
neg(x) = -x
pow2(x) = x^2
pow3(x) = x^3

# create the out file # ----------------------------------------------------------------------------
out_file_path = joinpath(out_dir_path, name)
if !isfile(out_file_path)
    open(out_file_path, "a") do io
        write(io, "run; gen; runtime; compl; exact; eq_str")
    end
else
    throw("result file already exits")
end

# ==================================================================================================
# callback function for early stopping
# ==================================================================================================

global last_called = time()

function callback(hall_of_fame, population, gen, t_since, prog_dict, ops)

    time() - last_called > 15 || return false
    global last_called = time()

    for indiv in hall_of_fame
        if indiv.measures[:max_are_test] <= ops.meta_data["accept_max_are_test"]
            str = string(TiSR.node_to_symbolic(indiv.node, ops))

            str = FastSRB.string_expl(str)
            str = SymPy.sympify(str) |> SymPy.simplify |> string
            str = FastSRB.round_equation_string(str, sigdigits = ops.meta_data["accept_param_sigdigits"])
            str = FastSRB.string_expl(str)

            if str in ops.meta_data["accept_eqs"]
                open(ops.meta_data["out_file_path"], "a") do io
                    write(io, "\n$(ops.meta_data["i_run"]); $gen; $t_since; 0; 1; $str")
                end
                return true
            end

            # write to close call file?
            ref_str = ops.meta_data["accept_eqs"][1]
            all(occursin(m.match, str) for m in eachmatch(r"v\d+", ref_str)) || continue # make sure all occuring variables are used
            FastSRB.get_binary_compl(str) <= ops.meta_data["accept_compl"]   || continue # not more than 20% more complex

            open(ops.meta_data["out_file_path"] * "_failed", "a") do io
                write(io, "\ni_run=$(ops.meta_data["i_run"]); $str")
            end
        end
    end
    return false
end

# ==================================================================================================
# run the benchmark
# ==================================================================================================
for i_run in 1:n_runs

    # sample data and prepare acceptable equations
    data_matr = FastSRB.sample_dataset(
        name, n_points = n_points, incremental=true
    )

    accept_eqs   = FastSRB.MAIN_BENCH[][name]["accept"]
    accept_eqs = map(accept_eqs) do eq
        str = FastSRB.round_equation_string(eq, sigdigits=accept_param_sigdigits)
        str = FastSRB.string_expl(str)
    end

    ref_eq_compl = FastSRB.get_binary_compl(accept_eqs[1])
    search_compl = trunc(Int64, ref_eq_compl * search_compl_incr)
    accept_compl = trunc(Int64, ref_eq_compl * accept_compl_incr)

    # options # ----------------------------------------------------------------------------
    ops, data =  Options(
        data_matr,
        data_split  = data_split_params(;parts = [train_test, 0.0, 1.0-train_test],),
        binops      = (+, -, *, /, ^),
        unaops      = (neg, exp, log, sqrt, pow2, pow3, sin, cos, tanh),
        general = general_params(
            t_lim              = t_lim,
            multithreading     = false,
            callback           = callback,
            print_progress     = false,
            plot_hall_of_fame  = false,
            print_hall_of_fame = false,
        ),
        grammar = grammar_params(
            max_compl    = search_compl,
            illegal_dict = Dict(
                "^"    => (lef = (),                     rig = ("+", "-", "*", "/", "^", "neg", "exp", "log", "sqrt", "pow2", "pow3", "sin", "cos", "tanh", "VAR")),
                "log"  => (lef = ("log", "exp"),         rig = ()),
                "exp"  => (lef = ("exp", "log"),         rig = ()),
                "sin"  => (lef = ("sin", "cos", "tanh"), rig = ()),
                "cos"  => (lef = ("sin", "cos", "tanh"), rig = ()),
                "tanh" => (lef = ("sin", "cos", "tanh"), rig = ()),
            ),
        ),
        selection = selection_params(;
            hall_of_fame_objectives = [:ms_processed_e, :compl],                          # -> objectives for the hall_of_fame
            selection_objectives    = [:ms_processed_e, :one_minus_abs_spearman, :compl], # -> objectives for the Pareto-optimal selection part of selection
        ),
        measures = measure_params(;
            additional_measures         =  Dict(
                :one_minus_abs_spearman => TiSR.get_measure_one_minus_abs_spearman,
                :mare                   => TiSR.get_measure_mare,
                :mare_test              => TiSR.get_measure_mare_test,
                :max_are_test           => TiSR.get_measure_max_are_test,
            ),
        ),
        meta_data = Dict(
            "accept_max_are_test"    => accept_max_are_test,
            "accept_param_sigdigits" => accept_param_sigdigits,
            "accept_compl"           => accept_compl,
            "accept_eqs"             => accept_eqs,
            "out_file_path"          => out_file_path,
            "i_run"                  => i_run,
        ),
    );

    # main generational loop # -------------------------------------------------------------------------
    hall_of_fame, population, prog_dict, stop_msg = generational_loop(data, ops);
end

