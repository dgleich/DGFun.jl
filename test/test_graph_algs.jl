
function test_flow_improve()
    
    A = connected_cliques([6,5,12],true) # get a connected ring
    R = Set{Int64}(1:5)
    push!(R,7)
    
    S,cval,vol,x = flow_improve(A,R)
    @assert S == Set(1:11)
    
    S,cval,vol,x = flow_improve(A,R;kappa=1)
    @assert S == Set(1:6)
    
    A = connected_cliques([5,5],false)
    R = Set{Int64}(1:5)
    A = sparse(A)
    S,cval,vol,x = flow_improve(A,R)

    @assert S == R

    R = Set{Int64}(6:10)
    S,cval,vol,x = flow_improve(A,R)

    @assert S == R  

    # this graph is disconnected, but MQI won't see it, but flow improve will
    A = connected_cliques([5,6,7,2,3,6,7],false)
    A[11,12] = 0. # disconnect these cliques
    A[12,11] = 0.
    R = Set{Int64}(6:18)
    S,cval,vol,x = flow_improve(A,R)

    @assert S == Set(1:11)
    @assert cval/vol == 0.0
    
    # so if we set kappa large enough (e^10 seems like enough)
    S,cval,vol,x = flow_improve(A,R; kappa = 10)
    
    @assert S == Set(12:18)
    @assert cval/vol == 0.023255813953488372
    
    A[1,end] = 1.
    A[end,1] = 1. # connect the ring
    
    S,cval,vol,x = flow_improve(A,R)
        
    @assert S == Set(12:18)
    @assert cval/vol == 0.023255813953488372
    
end

test_flow_improve()


function test_methods()
    A = sparse([0 5. 0.; 5. 2. 3.; 0. 3. 0.])
    
    B,w = incidence_matrix_and_weight(A)
    @test B == [1 -1. 0; 0. 1 -1]
    @test w == [5.; 3.]
    
    x,val = stmincut(A,1,3)
    @test val == 3
    @test x == [1.; 1.; 0.]
    
    A[1,2] = 1.5;
    
    x,val = stmincut(A,1,3)
    @test val == 1.5
    @test x == [1.; 0.; 0.]
    
    # mincut test from 
    # http://tcs.rwth-aachen.de/lehre/Graphentheorie/WS2013/Kiril_Mitev.pdf
    A = sparse([0 9 0 8 0.; 
                9 0 9 1 2;
                0 9 0 7 4;
                8 1 7 0 3;
                0 2 4 3 0])
    x,val = stmincut(A,1,5)
    @test val == 9.
    @test x == [1.; 1.; 1.; 1.; 0.]
    

    # create a pair of cliques and verify that we get back the same clique
    A = [ones(5,5) zeros(5,5); zeros(5,5) ones(5,5)]
    A[5,6] = 1.
    A[6,5] = 1.
    A = A - diagm(diag(A))
    R = Set{Int64}(1:5)
    A = sparse(A)
    S,cval,vol,x = mqi(A,R)
    
    @test S == R
    
    R = Set{Int64}(6:10)
    S,cval,vol,x = mqi(A,R)
    
    @test S == R  
    
    A = connected_cliques([5,6,7,2,3,6,7],false)
    A[11,12] = 0.
    A[12,11] = 0.
    R = Set{Int64}(6:18)
    S,cval,vol,x = mqi(A,R)
    
    @test S == Set(12:18)
    @test cval/vol == 0.023255813953488372
    
end    

test_methods()

