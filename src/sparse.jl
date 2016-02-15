function normout!(A::SparseMatrixCSC{Float64,Int64})
    d = sum(A,2) # sum over rows
    # use some internal julia magic
    for i=1:length(A.nzval)
        A.nzval[i] = A.nzval[i] / d[A.rowval[i]]
    end
    return A
end

export normout!