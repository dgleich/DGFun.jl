
import Base.LinAlg.checksquare
import Base.LinAlg.BlasFloat
import MathProgBase
import Clp


"""
This function computes the incidence matrix for the
matrix A assuming that it is symmetric, and only
uses the upper-triangular portion.
"""
function incidence_matrix_and_weight{T}(A::SparseMatrixCSC{T,Int64})
    n = checksquare(A)
    At = triu(A,1) # find the upper-triangular portion

    ei,ej,ev = findnz(At)
    m = length(ei)
    #@show length([1:m; 1:m]), length([ei; ej]), length([ones(T,m); -ones(T,m)])

    B = sparse([1:m; 1:m], [ei; ej], [ones(T,m); -ones(T,m)], m, n)
    return (B,ev)
end

export incidence_matrix_and_weight

function stmincut{T<:BlasFloat}(A::SparseMatrixCSC{T,Int64}, s::Int64, t::Int64)
    # create the mincut LP
    # minimize_x sum_(edge i,j) |w_{i,j} (x_i - x_j)| s.t. x_s = 1, x_t = 0
    # <->
    # minimize_x,y+,y- w'(y+ + y-)
    #   y+ - y- = B*x
    #   y+ >= 0
    #   y- >= 0
    #   x_s = 1, x_t = 0
    # <->
    # minimize_z [0 w' w']*z
    # s.t.
    #   [B -I +I]*[x; y+; y-] = B*x - y+ + y- = 0
    #   xs = 1
    #
    #   y+ >= 0

    B,w = incidence_matrix_and_weight(A)

    n = size(A,1)
    m = size(B,1)

    @assert 1 <= s <= n
    @assert 1 <= t <= n

    eint = Array(Int64,0)
    et = Array(T,0)

    zn = sparse(eint,eint,et,1,n)
    zm = sparse(eint,eint,et,1,m)
    es = sparse([1], [s], one(T), 1, n)
    et = sparse([1], [t], one(T), 1, n)

    f = [zeros(n); w; w]
    Aeq = [B -speye(m) speye(m);
           es zm zm;
           et zm zm]
    beq = [zeros(m); 1.; 0.]

    sol = MathProgBase.linprog(f, Aeq, '=', beq, 0., 1., Clp.ClpSolver())
    x = sol.sol[1:n]
    cutval = sol.objval

    return x, cutval, sol
end

export stmincut


function cut(A::SparseMatrixCSC{Float64,Int},R::Set{Int64})
    n = size(A,1)
    colptr = A.colptr
    rowval = A.rowval
    nzval = A.nzval
    cutval = 0.
    for z in R
        # z in a vertex in A
        for nzi in colptr[z]:(colptr[z+1] - 1)
            v = rowval[nzi]
            if !(v in R)
                cutval += nzval[nzi]
            end
        end
    end
    return cutval
end


function _create_mqi_reference_cut_graph(B,dr,dout,wcut,wvol)
    C = [spzeros(1,1) wcut*sparse(dr') spzeros(1,1);
        wcut*sparse(dr) wvol*B wvol*sparse(dout);
        spzeros(1,1) wvol*sparse(dout') spzeros(1,1)]
end

function mqi(A,R::Set{Int64};maxiter=10)

    # turn R into a vector
    rvec = collect(R)


    # get the degree vector
    d = sum(A,1) # get a summation
    dr = d[rvec]
    rvol = sum(dr)
    @assert rvol <= sum(d)/2

    # get the initial cut
    cutval = cut(A,R)

    B = A[rvec,rvec]
    dout = dr-vec(sum(B,1))

    nb = size(B,1)

    W = deepcopy(R) # make a copy
    wvol = rvol
    wcut = cutval

    @printf("mqi: cut=%7.2g  vol=%7.2g  r=%.5f graph-edges=%7i\n", wcut, wvol, wcut/wvol, 0)

    # create the st graph
    C = _create_mqi_reference_cut_graph(B,dr,dout,wcut,wvol)
    x,val = stmincut(C,1,size(C,1))
    #display(full(C))

    iter = 1


    # add the MQI loop
    while val < wvol*wcut && iter <= maxiter

        # then there is a smaller conductance set inside
        W = Set{Int64}(rvec[find(x[2:end-1] .> 0.5)]) # TODO handle non-integer solutions
        wcut = cut(A,W)
        wvol = sum(dr[ x[2:end-1] .> 0.5 ])

        @printf("mqi: cut=%7.2g  vol=%8.2g  r=%.5f iter=%3i\n", wcut, wvol, wcut/wvol, iter)

        C = _create_mqi_reference_cut_graph(B,dr,dout,wcut,wvol)
        x,val = stmincut(C,1,size(C,1))

        iter += 1
    end

    @printf("mqi: cut=%7.2g  vol=%8.2g  r=%.5f iter=%3i\n", wcut, wvol, wcut/wvol, iter)

    if iter == maxiter && val < wvol*wcut
        warn("iteration hit limit")
    end

    #S = Set{Int64}(find(x[2:end-1] .> 0.5))
    S = W

    return S, wcut, wvol, x

end

export mqi


function _create_flow_improve_reference_cut_graph(A,dr,drbar,alpha,ep)
    C = [spzeros(1,1) alpha*dr' spzeros(1,1);
        alpha*dr A alpha*ep*sparse(drbar);
        spzeros(1,1) alpha*ep*sparse(drbar') spzeros(1,1)]
end

function flow_improve(A,R::Set{Int64};maxiter=10,kappa=0.)

    # kappa is the parameter that controls the localization
    # kappa = 0. is the original flow improve algorithm
    # kappa > 0. gives the Orecchia & Zhu locally modified
    # version

    n = size(A,1)

    # turn R into a vector
    rvec = collect(R)
    rbarvec = setdiff(1:n,rvec)

    # get the degree vector
    d = sum(A,1) # get a summation
    rvol = sum(d[rvec])
    gvol = sum(d)
    @assert rvol <= gvol/2

    ep = (rvol/(gvol-rvol))*exp(kappa)

    # get the initial cut
    cutval = cut(A,R)

    dr = sparse(rvec,ones(Int64,length(rvec)),d[rvec],n,1)
    drbar = sparse(rbarvec,ones(Int64,length(rbarvec)),d[rbarvec],n,1)

    W = deepcopy(R) # make a copy

    wvol = rvol
    wadjvol = rvol # initially the adjusted volume is the same
    wcut = cutval
    alpha = wcut/wadjvol
    alphaold = alpha

    @printf("flow_improve: cut=%15g  vol=%15g  r=%.5f  alpha=%.5f graph-edges=%7i\n",
                wcut, wvol, wcut/wvol, alpha, gvol)

    # create the st graph
    C = _create_flow_improve_reference_cut_graph(A,dr,drbar,alpha,ep)
    x,val = stmincut(C,1,size(C,1))

    #@printf("Target val: %15g\n", alpha*rvol - alpha*wadjvol + wcut)
    #@printf(" Flow  val: %15g\n", val)

    iter = 1

    #@show val, alpha*wvol + wcut - alpha*wadjvol, wcut, wvol, wadjvol, alpha, ep


    # add the loop
    while val < alpha*rvol - alpha*wadjvol + wcut && iter <= maxiter



        # the cost of a cut in graph C is
        # alpha*rvol - alpha*adjusted-vol + cut
        # so our current score is
        # alpha*rvol - alpha*wadjvol + cut
        # and if the previous computation gave a better score,
        # then we found a better set!

        alphaold = alpha

        # get the cut and compute it's value
        W = Set{Int64}(find(x[2:end-1] .> 0.5)) # TODO handle non-integer solutions
        wcut = cut(A,W)
        wvol = sum(d[ x[2:end-1] .> 0.5 ])
        wadjvol = sum( dr[collect(W)]) - ep*sum(drbar[collect(W)])
        alpha = wcut/wadjvol

        if alphaold <= alpha
            # due to some floating point issues, we might not have detected
            # the stopping condition above, this check will get it
            # essentially, we made no progress, which means the algorithm
            # will stall
            break
        end

        @printf("flow_improve: cut=%15g  vol=%15g  r=%.5f  alpha=%.5f iter=%3i\n", wcut, wvol, wcut/wvol, alpha, iter)

        C = _create_flow_improve_reference_cut_graph(A,dr,drbar,alpha,ep)

        x,val = stmincut(C,1,size(C,1))

        #@printf("finished iteration %i: val=%.16f, cut=%16g, vol=%16g, alpha=%16g\n", iter, val, wcut, wvol, alpha )

        iter += 1
    end

    @printf("flow_improve: cut=%15g  vol=%15g  r=%.5f  alpha=%.5f iter=%3i (done)\n", wcut, wvol, wcut/wvol, alpha, iter)

    if iter == maxiter && alpha < alphaold
        warn("iteration hit limit")
    end

    S = W

    return S, wcut, wvol, x
end

export flow_improve


function connected_cliques(sizes::Vector{Int64},ring::Bool)
    # TODO add xy coords
    # create the index sets for each clique
    n = 0
    nedges = 2*(length(sizes)-1) # the number of connecting edges
    for s in sizes
        nedges += s*(s-1)
        n += s
    end
    if ring
        nedges += 2
    end

    ei = zeros(Int64,nedges)
    ej = zeros(Int64,nedges)

    z = 1
    offset = 0
    for s in sizes
        # create a clique of size s with edges starting at z
        for i=1:s
            for j=1:s
                if i==j
                    continue
                end
                ei[z] = i+offset
                ej[z] = j+offset
                z += 1
            end
        end

        # add the connection
        offset += s
        if offset < n
            # we aren't at the end yet
            ei[z] = offset
            ej[z] = offset + 1
            z += 1
            ei[z] = offset + 1
            ej[z] = offset
            z += 1
        end
    end

    if ring
        ei[z] = n
        ej[z] = 1
        z += 1
        ei[z] = 1
        ej[z] = n
        z += 1
    end

    @assert z == nedges + 1
    A = sparse(ei,ej,1.,n,n)
    return A
end

export connected_cliques
