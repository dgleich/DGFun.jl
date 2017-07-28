@testset "fastio" begin
  data = [1/3*ones(500); pi*ones(500); nextfloat(0.0)*ones(500)]
  buf = IOBuffer()
  for i in data
    print(buf, i)
    print(buf, " ")
  end
  seek(buf, 0) # reset buffer
  a = DGFun.tseq(buf, zeros(0))
  @test a == data
end
