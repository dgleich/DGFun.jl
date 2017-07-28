@testset "filter_topk" begin

  @test_throws ArgumentError filter_topk(spzeros(5,5), -1)

  A = sparse([1.0 2.0 3.0;
       4.0 5.0 6.0;
       7.0 8.0 9.0])

  B = Array(filter_topk(A,1))
  @test B == [0.0 0.0 0.0;
              0.0 0.0 0.0;
              7.0 8.0 9.0]

  B = Array(filter_topk(A,0))
  @test B == [0.0 0.0 0.0;
              0.0 0.0 0.0;
              0.0 0.0 0.0]

  B = Array(filter_topk(sparse(
             [0.0 0.0 0.0;
              0.0 0.0 0.0]
  ), 1))
  @test B == [0.0 0.0 0.0;
              0.0 0.0 0.0]

  @test filter_topk!(spzeros(0,0),0) == spzeros(0,0)
  @test filter_topk!(spzeros(0,0),5) == spzeros(0,0)

  @test filter_topk!(spzeros(0,5),5) == spzeros(0,5)
  @test filter_topk!(spzeros(5,0),5) == spzeros(5,0)

  @test filter_topk!(spzeros(4,5),5) == spzeros(4,5)

  @test filter_topk!(spzeros(4,5),5) == spzeros(4,5)

  B = Array(filter_topk(sparse(
             [2.0 3.0 5.0;
              0.0 0.0 6.0;
              0.0 0.5 0.5]
  ), 3))
  @test B == [2.0 3.0 5.0;
   0.0 0.0 6.0;
   0.0 0.5 0.5]

end
