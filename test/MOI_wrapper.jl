module TestMOIWrapper

using PATHSolver
using Test

using MathOptInterface
const MOI = MathOptInterface

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_Name()
    model = PATHSolver.Optimizer()
    @test MOI.get(model, MOI.SolverName()) == PATHSolver.c_api_Path_Version()
    return
end

function test_AbstractOptimizer()
    @test PATHSolver.Optimizer() isa MOI.AbstractOptimizer
    return
end

function test_DualStatus()
    @test MOI.get(PATHSolver.Optimizer(), MOI.DualStatus()) == MOI.NO_SOLUTION
    return
end

function test_RawOptimizerAttribute()
    model = PATHSolver.Optimizer()
    @test MOI.get(model, MOI.RawOptimizerAttribute("output")) === nothing
    MOI.set(model, MOI.RawOptimizerAttribute("output"), "no")
    @test MOI.get(model, MOI.RawOptimizerAttribute("output")) == "no"
    return
end

function test_infeasible()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(model, x, MOI.Interval(0.0, -1.0))
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.INVALID_MODEL
    @test MOI.get(model, MOI.RawStatusString()) == "Problem has a bound error"
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.UNKNOWN_RESULT_STATUS
end

function test_ZeroOne()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    @test !MOI.supports_constraint(model, MOI.VariableIndex, MOI.ZeroOne)
    return
end

function test_wrong_dimension()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{Float64}[], [0.0]),
        MOI.Complements(2),
    )
    @test_throws(
        ErrorException(
            "Dimension of constant vector 1 does not match the required dimension of " *
            "the complementarity set 2.",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_nonzero_variable_offset()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x)),
            ],
            [0.0, 1.0],
        ),
        MOI.Complements(2),
    )
    @test_throws(
        ErrorException(
            "VectorAffineFunction malformed: a constant associated with a " *
            "complemented variable is not zero: [1.0].",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_output_dimension_too_large()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(3, MOI.ScalarAffineTerm(1.0, x)),
            ],
            [0.0, 0.0],
        ),
        MOI.Complements(2),
    )
    @test_throws(
        ErrorException(
            "VectorAffineFunction malformed: output_index 3 is too large.",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_missing_complement_variable()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(
            [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x))],
            [0.0, 0.0],
        ),
        MOI.Complements(2),
    )
    @test_throws(
        ErrorException(
            "VectorAffineFunction malformed: expected variable in row 2.",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_output_dimension_too_large()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(2.0, x)),
            ],
            [0.0, 0.0],
        ),
        MOI.Complements(2),
    )
    @test_throws(
        ErrorException(
            "VectorAffineFunction malformed: variable $(x) has a coefficient that is " *
            "not 1 in row 2 of the VectorAffineFunction.",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_variable_in_multiple_constraints()
    model = PATHSolver.Optimizer()
    x = MOI.add_variable(model)
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(
            [
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(3, MOI.ScalarAffineTerm(1.0, x)),
                MOI.VectorAffineTerm(4, MOI.ScalarAffineTerm(1.0, x)),
            ],
            [0.0, 0.0, 0.0, 0.0],
        ),
        MOI.Complements(4),
    )
    @test_throws(
        ErrorException(
            "The variable $(x) appears in more than one complementarity constraint.",
        ),
        MOI.optimize!(model)
    )
    return
end

function test_Example_I()
    model = PATHSolver.Optimizer()
    MOI.set(model, MOI.RawOptimizerAttribute("time_limit"), 60)
    @test MOI.supports(model, MOI.Silent()) == true
    @test MOI.get(model, MOI.Silent()) == false
    MOI.set(model, MOI.Silent(), true)
    @test MOI.get(model, MOI.Silent()) == true
    x = MOI.add_variables(model, 4)
    @test MOI.supports(model, MOI.VariablePrimalStart(), MOI.VariableIndex)
    @test MOI.get(model, MOI.VariablePrimalStart(), x[1]) === nothing
    MOI.add_constraint.(model, x, MOI.Interval(0.0, 10.0))
    MOI.set.(model, MOI.VariablePrimalStart(), x, 0.0)
    M = Float64[
        0 0 -1 -1
        0 0 1 -2
        1 -1 2 -2
        1 2 -2 4
    ]
    q = [2; 2; -2; -6]
    for i in 1:4
        terms = [MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[i]))]
        for j in 1:4
            iszero(M[i, j]) && continue
            push!(
                terms,
                MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(M[i, j], x[j])),
            )
        end
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(terms, [q[i], 0.0]),
            MOI.Complements(2),
        )
    end
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.NO_SOLUTION
    @test MOI.get(model, MOI.RawStatusString()) ==
          "MOI.optimize! was not called yet"
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.LOCALLY_SOLVED
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.RawStatusString()) == "The problem was solved"
    x_val = MOI.get.(model, MOI.VariablePrimal(), x)
    @test isapprox(x_val, [2.8, 0.0, 0.8, 1.2])
    return
end

# An implementation of the GAMS model transmcp.gms: transporation model
# as an equilibrium problem.
#
# https://www.gams.com/latest/gamslib_ml/libhtml/gamslib_transmcp.html
#
# Transportation model as equilibrium problem (TRANSMCP,SEQ=126)
#
#    Dantzig's original transportation model (TRNSPORT) is
#    reformulated as a linear complementarity problem.  We first
#    solve the model with fixed demand and supply quantities, and
#    then we incorporate price-responsiveness on both sides of the
#    market.
#
# Dantzig, G B, Chapter 3.3. In Linear Programming and Extensions.
# Princeton University Press, Princeton, New Jersey, 1963.
function test_transmcp()
    plants = ["seattle", "san-diego"]
    P = length(plants)
    capacity = Dict("seattle" => 350, "san-diego" => 600)
    markets = ["new-york", "chicago", "topeka"]
    M = length(markets)
    demand = Dict("new-york" => 325, "chicago" => 300, "topeka" => 275)
    distance = Dict(
        ("seattle" => "new-york") => 2.5,
        ("seattle" => "chicago") => 1.7,
        ("seattle" => "topeka") => 1.8,
        ("san-diego" => "new-york") => 2.5,
        ("san-diego" => "chicago") => 1.8,
        ("san-diego" => "topeka") => 1.4,
    )
    model = PATHSolver.Optimizer()
    MOI.set(model, MOI.Silent(), true)
    # w[i in plants] >= 0
    w = MOI.add_variables(model, P)
    MOI.add_constraint.(model, w, MOI.GreaterThan(0.0))
    # p[j in markets] >= 0
    p = MOI.add_variables(model, M)
    MOI.add_constraint.(model, p, MOI.GreaterThan(0.0))
    # x[i in plants, j in markets] >= 0
    x = reshape(MOI.add_variables(model, P * M), P, M)
    MOI.add_constraint.(model, x, MOI.GreaterThan(0.0))
    # w[i] + 90 * distance[i => j] / 1000 - p[j] ⟂ x[i, j]
    for (i, plant) in enumerate(plants), (j, market) in enumerate(markets)
        MOI.add_constraint(
            model,
            MOI.VectorAffineFunction(
                [
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1.0, w[i])),
                    MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(-1.0, p[j])),
                    MOI.VectorAffineTerm(2, MOI.ScalarAffineTerm(1.0, x[i, j])),
                ],
                [90 * distance[plant=>market] / 1000, 0.0],
            ),
            MOI.Complements(2),
        )
    end
    # capacity[i] - sum(x[i, :]) ⟂ w[i]
    terms = MOI.VectorAffineTerm{Float64}[]
    for (i, plant) in enumerate(plants)
        for j in 1:M
            push!(
                terms,
                MOI.VectorAffineTerm(i, MOI.ScalarAffineTerm(-1.0, x[i, j])),
            )
        end
        push!(
            terms,
            MOI.VectorAffineTerm(P + i, MOI.ScalarAffineTerm(1.0, w[i])),
        )
    end
    q = vcat([capacity[p] for p in plants], zeros(P))
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(terms, q),
        MOI.Complements(2 * P),
    )
    # sum(x[:, j]) - demand[j] ⟂ p[j]
    terms = MOI.VectorAffineTerm{Float64}[]
    for (j, market) in enumerate(markets)
        for i in 1:P
            push!(
                terms,
                MOI.VectorAffineTerm(j, MOI.ScalarAffineTerm(1.0, x[i, j])),
            )
        end
        push!(
            terms,
            MOI.VectorAffineTerm(M + j, MOI.ScalarAffineTerm(1.0, p[j])),
        )
    end
    q = vcat([-demand[m] for m in markets], zeros(M))
    MOI.add_constraint(
        model,
        MOI.VectorAffineFunction(terms, q),
        MOI.Complements(2 * M),
    )
    MOI.optimize!(model)
    @test isapprox(
        MOI.get.(model, MOI.VariablePrimal(), p),
        [0.225, 0.153, 0.126],
        atol = 1e-3,
    )
    return
end

end

TestMOIWrapper.runtests()
