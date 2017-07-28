function normout!(A::SparseMatrixCSC{Float64,Int64})
    d = sum(A,2) # sum over rows
    # use some internal julia magic
    for i=1:length(A.nzval)
        A.nzval[i] = A.nzval[i] / d[A.rowval[i]]
    end
    return A
end

export normout!

##

""" Filter out the entries that are not in the topk list for each column. """
function filter_topk!(A::SparseMatrixCSC, k::Integer)

  k < 0 && throw(ArgumentError("The value of k = $k must be non-negative"))
  rows = rowvals(A)
  vals = nonzeros(A)
  m, n = size(A)
  sortarr = Array{eltype(A)}(m)
  permarr = Array{Int}(m)

  for i = 1:n
    currange = nzrange(A,i)
    if length(currange) <= k
      continue
    end
    first = currange[1]
    last = currange[end]
    len = last-first+1

    resize!(sortarr, len)
    resize!(permarr, len)
    copy!(sortarr, 1, vals, first, len)
    sortperm!(permarr, sortarr, order=Base.Order.Reverse)
    for j in nzrange(A, i) # clear out the results
      vals[j] = 0
    end
    # at this point, sortarr is still untouched, so
    # sortarr[j] -> currange[j]
    for (j, ji) in enumerate(permarr)
      if j > k # last one! we are done
        break
      end
      #sortarr[ji] is an entry we want to return!
      vals[currange[ji]] = sortarr[ji]
    end
  end
  dropzeros!(A)
end
filter_topk(A,k) = dropzeros!(filter_topk!(copy(A),k))

export filter_topk, filter_topk!
