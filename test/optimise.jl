opts = [STRRidge(), ADMM(), SR3()]
iters = Int64[500, 1000, 10000]
atols = Float64[1e-3, 1e-2, 2e-1]

@testset "Equal Sizes" begin

    x = randn(3, 10)
    A = [1.0 0 -0.1; 0 -2.0 0; 0.1 0.5 -1.0]
    y = A*x

    threshold = 0.9*minimum(abs.(A[abs.(A) .> 0.0]))

    @testset for (opt, maxiter, a_tol) in zip(opts, iters, atols)
        set_threshold!(opt, threshold)
        Ξ = DataDrivenDiffEq.Optimise.init(opt, x', y')
        fit!(Ξ, x', y', opt, maxiter = maxiter)
        @test A ≈ Ξ' atol = a_tol
    end
end

@testset "Single Signal" begin

    x = randn(3, 10)
    A = [1.0 0 -0.1]
    y = A*x

    threshold = 0.9*minimum(abs.(A[abs.(A) .> 0.0]))

    @testset for (opt, maxiter, a_tol) in zip(opts, iters, atols)
        set_threshold!(opt, threshold)
        Ξ = DataDrivenDiffEq.Optimise.init(opt, x', y')
        fit!(Ξ, x', y', opt, maxiter = maxiter)
        @test A ≈ Ξ' atol = a_tol
    end
end


@testset "Multiple Signals" begin

    x = randn(100, 500)
    A = zeros(5,100)
    A[1,1] = 1.0
    A[1, 50] = 3.0
    A[2, 75] = 10.0
    A[3, 5] = -2.0
    A[4,80] = 0.2
    A[5,5] = 0.1
    y = A*x
    threshold =0.9*minimum(abs.(A[abs.(A) .> 0.0]))

    @testset for (opt, maxiter, a_tol) in zip(opts, iters, atols)
        set_threshold!(opt, threshold)
        Ξ = DataDrivenDiffEq.Optimise.init(opt, x', y')
        fit!(Ξ, x', y', opt, maxiter = maxiter)
        @test A ≈ Ξ' atol = a_tol
    end
end

@testset "ADM" begin
    x = randn(3, 100)
    A = Float64[1 0 3; 0 1 0; 0 2 1]
    @testset "Linear" begin
        Z = A*x # Measurements
        Z[1, :] = Z[1,:] ./ (1 .+ x[2,:])
        θ = [Z[1,:]'; Z[1,:]' .* x[1,:]';Z[1,:]' .* x[2,:]';Z[1,:]' .* x[3,:]'; x[1,:]'; x[2,:]'; x[3,:]']
        M = nullspace(θ', rtol = 0.99)
        L = deepcopy(M)
        opt = ADM(1e-2)
        fit!(M, L', opt, maxiter = 10000)
        @test all(norm.(eachcol(M)) .≈ 1)
        @test norm(θ'*L) ≈ norm(θ'*M)
        pareto = map(q->norm([norm(q, 0) ;norm(θ'*q, 2)], 2), eachcol(M))
        score, posmin = findmin(pareto)
        # Get the corresponding eqs
        q_best = M[:, posmin] ./ M[1, posmin]
        @test q_best ≈ [1.0 0 1.0 0 -1 0 -3]'
    end

    @testset "Quadratic" begin
        Z = A*x # Measurements
        Z[1, :] = Z[1,:] ./ (1 .+ x[2,:].*x[1,:])
        θ = [Z[1,:]'; Z[1,:]' .* x[1,:]';Z[1,:]' .* x[2,:]';Z[1,:]' .* x[3,:]'; Z[1,:]' .* (x[1,:].*x[2,:])'; x[1,:]'; x[2,:]'; x[3,:]']
        M = nullspace(θ', rtol = 0.99)
        L = deepcopy(M)
        opt = ADM(1e-2)
        fit!(M, L', opt, maxiter = 10000)
        @test all(norm.(eachcol(M)) .≈ 1)
        @test norm(θ'*L) ≈ norm(θ'*M)
        pareto = map(q->norm([norm(q, 0) ;norm(θ'*q, 2)], 2), eachcol(M))
        score, posmin = findmin(pareto)
        # Get the corresponding eqs
        q_best = M[:, posmin] ./ M[1, posmin]
        @test q_best ≈ [1.0 0 0.0 0.0 1.0 -1 0 -3]'
    end

    @testset "Nonlinear" begin
        Z = A*x # Measurements
        Z[1, :] = Z[1,:] ./ (2 .+ sin.(x[1,:]))
        θ = [Z[1,:]'; Z[1,:]' .* x[1,:]';Z[1,:]' .* x[2,:]';Z[1,:]' .* x[3,:]'; Z[1,:]' .* (x[1,:].*x[2,:])';Z[1,:]' .* sin.(x[1,:])' ;x[1,:]'; x[2,:]'; x[3,:]']
        M = nullspace(θ', rtol = 0.99)
        L = deepcopy(M)
        opt = ADM(1e-2)
        fit!(M, L', opt, maxiter = 10000)
        @test all(norm.(eachcol(M)) .≈ 1)
        @test norm(θ'*L) ≈ norm(θ'*M)
        pareto = map(q->norm([norm(q, 0) ;norm(θ'*q, 2)], 2), eachcol(M))
        score, posmin = findmin(pareto)
        # Get the corresponding eqs
        q_best = M[:, posmin] ./ M[1, posmin]
        @test q_best ≈ [1.0 0 0.0 0.0 0.0 0.5 -0.5 0 -1.5]'
    end
end
