
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using DataFrames
using SymPy
using SymbolicUtils
using Random

using SymbolicRegression

using FastSRB

# which benchmark problem to run # -----------------------------------------------------------------
name = ARGS[1]

# benchmark settings # -----------------------------------------------------------------------------
out_dir_path = "results/pysr/"

n_runs            = 5
t_lim             = 60.0 * 30.0
n_points          = 400
train_test        = 0.5

search_compl_incr = 1.5
accept_compl_incr = 1.2

accept_max_are_test    = 1e-8
accept_param_sigdigits = 5

# custom functions # -------------------------------------------------------------------------------
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
# helper function -> could not get Miles' version to work
# ==================================================================================================
function nnnode_to_symbolic(node, ops)
    if node.degree == 0
        if node.constant
            return node.val
        else
            return SymbolicUtils.Sym{Real}(Symbol("v$(node.feature)"))
        end
    elseif node.degree == 1
        l = nnnode_to_symbolic(node.l, ops)
        return ops.unaops[node.op](l)
    elseif node.degree == 2
        l = nnnode_to_symbolic(node.l, ops)
        r = nnnode_to_symbolic(node.r, ops)
        return ops.binops[node.op](l, r)
    end
end

# ==================================================================================================
# run the benchmark
# ==================================================================================================
for i_run in 1:n_runs

    # sample data and prepare acceptable equations
    data_matr = FastSRB.sample_dataset(
        name, n_points = n_points, incremental=true
    )

    # preapre the data
    eachind = collect(1:n_points)
    shuffle!(eachind)

    train_inds = eachind[1:round(Int, n_points * train_test)]
    test_inds  = eachind[round(Int, n_points * train_test) + 1:n_points]

    X = copy(data_matr[train_inds, 1:end-1]')
    y = data_matr[train_inds, end]

    X_test = copy(data_matr[test_inds, 1:end-1]')
    y_test = data_matr[test_inds, end]

    accept_eqs   = [FastSRB.string_expl(FastSRB.round_equation_string(s, sigdigits = accept_param_sigdigits)) for s in FastSRB.MAIN_BENCH[][name]["accept"]]
    ref_eq_compl = FastSRB.get_binary_compl(accept_eqs[1])
    search_compl = trunc(Int64, ref_eq_compl * search_compl_incr)
    accept_compl = trunc(Int64, ref_eq_compl * accept_compl_incr)

    # ======================================================================================
    # callback function
    # ======================================================================================
    function callback(member, options)
        pred, valid = eval_tree_array(member.tree.tree, X_test, options.operators)
        valid || return false

        max_are_test = maximum(abs, (pred .- y_test) ./ (abs.(y_test) .+ 1e-100))
        max_are_test < accept_max_are_test || return false

        str = string(nnnode_to_symbolic(member.tree.tree, options.operators))

        str = FastSRB.string_expl(str)
        str = SymPy.sympify(str) |> SymPy.simplify |> string
        str = FastSRB.round_equation_string(str, sigdigits=accept_param_sigdigits)
        str = FastSRB.string_expl(str)

        if str in accept_eqs
            open(out_file_path, "a") do io
                write(io, "\n$i_run; gen; t_since; 0; 1; $str")
            end
            return true
        end

        # write to close call file?
        ref_str = accept_eqs[1]
        all(occursin(m.match, str) for m in eachmatch(r"v\d+", ref_str)) || return false # make sure all occuring variables are used
        FastSRB.get_binary_compl(str) <= accept_compl                    || return false # not more than 20% more complex

        open(out_file_path * "_failed", "a") do io
            write(io, "\ni_run=$i_run; $str")
        end
        return false
    end

    # function my_loss(tree, dataset::Dataset{T,L}, options)::L where {T,L}
    #     prediction, flag = eval_tree_array(tree, dataset.X, options)
    #     if !flag
    #         return L(Inf)
    #     end
    #     return sum(abs2, (prediction .- dataset.y) ./ (abs.(dataset.y) .+ 1e-100))
    # end

    # ======================================================================================
    # start expression search
    # ======================================================================================
    options = SymbolicRegression.Options(
        binary_operators     = (+, *, /, -, ^),
        unary_operators      = (neg, exp, log, sqrt, pow2, pow3, sin, cos, tanh),
        timeout_in_seconds   = t_lim,
        early_stop_condition = callback,
        maxsize              = search_compl,
        nested_constraints = [
            log  => [log => 0, exp => 0],
            exp  => [log => 0, exp => 0],
            sin  => [sin => 0, cos => 0, tanh => 0],
            cos  => [sin => 0, cos => 0, tanh => 0],
            tanh => [sin => 0, cos => 0, tanh => 0],
        ],
        # complexity_of_constants = 1.2,    # seems to make it worse?
        # complexity_of_variables = 1.0,    # seems to make it worse?
        # complexity_of_operators = [       # seems to make it worse?
        #     (+)     => 1.2, (-)     => 1.4, (*)     => 1.0, (/)     => 1.6, (^)     => 3.0,
        #     (pow)   => 3.5, (neg)   => 1.4, (sqrt)  => 2.0, (pow2)  => 2.0, (pow3)  => 2.1,
        #     (sin)   => 3.0, (cos)   => 3.0, (tanh)  => 3.0, (exp)   => 3.0, (log)   => 3.0,
        # ],
        # loss_function = my_loss,          # seems to make it worse?
        save_to_file = false,
        verbosity    = 0,
    )

    hall_of_fame = EquationSearch(
        X, y,
        niterations = 1_000_000_000_000, # typemax(Int64) does not seem to work
        options     = options,
        parallelism = :serial,
        progress    = false,
    )
end
