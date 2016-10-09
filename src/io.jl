function readSMAT(filename::AbstractString)
    (rows,header) = readdlm(filename;header=true)
    A = sparse(
               convert(Array{Int64,1},rows[1:parse(Int,header[3]),1])+1,
               convert(Array{Int64,1},rows[1:parse(Int,header[3]),2])+1,
               convert(Array{Float64,1},rows[1:parse(Int,header[3]),3]),
               parse(Int,header[1]),
               parse(Int,header[2])
               )
    return A
end

export readSMAT

function writeSMAT{T}(filename::AbstractString, A::SparseMatrixCSC{T,Int}; values::Bool=true)
    open(filename, "w") do outfile
        write(outfile, join((size(A,1), size(A,2), nnz(A)), " "), "\n")
        
        rows = rowvals(A)
        vals = nonzeros(A)
        m, n = size(A)
        for j = 1:n
           for nzi in nzrange(A, j)
              row = rows[nzi]
              val = vals[nzi]
              if values
                write(outfile, join((row-1, j-1, val), " "), "\n")
              else
                write(outfile, join((row-1, j-1, 1), " "), "\n")
              end
           end
        end
    end
end

export writeSMAT