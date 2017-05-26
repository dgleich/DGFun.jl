
import Base.AbstractSet
type IntListSet  <: AbstractSet{Int}
    list::Vector{Int} # the current list
    indv::Vector{Int} # the current location indicator (for fast deletion)
    n::Int
    IntListSet(indmax::Integer) = new(Vector{Int}(), zeros(Int,indmax), 0)
end


import Base.eltype, Base.similar
eltype(::Type{IntListSet}) = Int
similar(s::IntListSet) = IntListSet(length(s.indv))

""" Change the position of an element in the list of element. """
function swap_positions!(s::IntListSet, i1::Int, i2::Int)
  v1 = s.list[i1]
  v2 = s.list[i2]
  s.list[i1],s.list[i2] = v2,v1 # swap positions in list
  s.indv[v1] = i2
  s.indv[v2] = i1
  return (v1,v2)
end

""" Remove an element by moving it to the end of the list and removing it. """
function pivot_out!(s::IntListSet, listindex::Int)
  v = swap_positions!(s, listindex, s.n)[1]
  s.indv[v] = 0 # remove it
  s.n -= 1 # reduce the size
end

import Base.push!
function push!(s::IntListSet, v::Int)
  0 < v <= length(s.indv) || throw(
    ArgumentError("IntListSet items must be between [1,$(length(s.indv))]"))
  if s.indv[v] == 0 # this is not here
    s.n += 1
    s.indv[v] = s.n
    if length(s.list) < s.n
      push!(s.list, v)
    else
      s.list[s.n] = v
    end
  end
  return s
end

import Base.delete!
function delete!(s::IntListSet, v::Int)
  0 < v <= length(s.indv) || throw(
    KeyError("IntListSet items must be between [1,$(length(s.indv))]"))
  if s.indv[v] > 0 # this is here
    pivot_out!(s, s.indv[v])
  end
  return s
end

import Base.in
function in(v::Int, s::IntListSet)
  if 0 < v <= length(s.indv)
    @inbounds return s.indv[v] > 0
  else
    return false
  end
end

import Base.pop!
pop!(s::IntListSet) = pop!(s::IntListSet, s.list[s.n])
function pop!(s::IntListSet, n::Integer)
  if n in s
    return (delete!(s, n), n)
  else
    throw(KeyError(n))
  end
end
function pop!(s::IntListSet, n::Integer, default)
  if n in s
    return (delete!(s, n), n)
  else
    return default
  end
end

import Base.empty!
function empty!(s::IntListSet)
  for i in 1:s.n
    s.indv[s.list[i]] = 0
  end
  s.n = 0
  return s
end

# Just iterate over the elements in list order
import Base.start, Base.next, Base.done
start(s::IntListSet) = 1
done(s::IntListSet, i) = i > s.n
next(s::IntListSet, i) = (s.list[i], i+1)

import Base.intersect!
function intersect!(s::IntListSet, iterable)
    front = 1
    for i in iterable
        if i in s
          # okay, but pivot to front of list
          swap_positions!(s, front, s.indv[i])
          front += 1
        else
          delete!(s, i)
        end
    end
    # now remove everything from front:s.n
    for i in front:s.n # this captures the value at the start of the loop
      #ideally, just delete!(s, s.list[i]), but that pivots stuff around
      s.indv[s.list[i]] = 0
    end
    s.n = front - 1
    s
end

import Base.length
length(s::IntListSet) = s.n

import Base.Random.rand
rand(r::AbstractRNG,s::IntListSet) = rand(r, @view s.list[1:s.n])
rand(s::IntListSet) = rand(@view s.list[1:s.n])

import Base.show, Base.show_vector
function show(io::IO, s::IntListSet)
  print(io, "IntListSet(")
  show_vector(io,view(s.list,1:s.n),"[","]")
  print(io, ")")
end

export IntListSet
