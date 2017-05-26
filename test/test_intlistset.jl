
using Base.Test

@testset "Simple IntListSet Test" begin
  s = IntListSet(5)
  @show s
  push!(s, 5)
  @show s
  @test 5 in s
  @test 6 ∉ s
  @test_throws ArgumentError push!(s, 6)
  @test_throws ArgumentError push!(s, 0)
  @test_throws ArgumentError push!(s, -1)
  push!(s, 1)
  push!(s, 2)
  push!(s, 5)
  @test length(s) == 3
  @test setdiff(collect(s),[1,2,5]) == []
  delete!(s, 1)
  @test setdiff(collect(s),[2,5]) == []
  push!(s, 1)
  push!(s, 3)
  intersect!(s, [1,2])
  @test length(s) == 2
  intersect!(s, [1,3])
  @test length(s) == 1
  for i=1:5
    push!(s, i)
  end
  @test length(s) == 5
end
