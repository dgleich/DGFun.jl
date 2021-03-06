function readSMAT(filename::AbstractString, indextype::Type, valuetype::Type)
    (rows,header) = readdlm(filename;header=true)
    m = parse(indextype,header[1])
    n = parse(indextype,header[2])
    nz = parse(Int64,header[3])
    assert(size(rows,1) == nz)
    A = sparse(
               convert(Array{indextype,1},rows[:,1])+1,
               convert(Array{indextype,1},rows[:,2])+1,
               convert(Array{valuetype,1},rows[:,3]),
               parse(Int,header[1]),
               parse(Int,header[2])
               )
    return A
end

readSMAT(filename) = readSMAT(filename, Int64, Float64)


# readSMATtoCSC
# readSMATtoCSR
# readSMATtoEdges

function _read_bz2(file::AbstractString)
  cf, p = open(`zcat $(file)`, "r", STDOUT)
  return eachline(cf)
end

function _read_xz(file::AbstractString)
  cf, p = open(`zcat $(file)`, "r", STDOUT)
  return eachline(cf)
end

function _read_gz(file::AbstractString)
  cf, p = open(`zcat $(file)`, "r", STDOUT)
  return eachline(cf)
end



function _read_compressed(filename::AbstractString)
  if     endswith(filename,".gz")
    return _read_gz(filename)
  elseif endswith(filename,".bz2")
    return _read_bz2(filename)
  elseif endswith(filename,".xz")
    return _read_xz(filename)
  else
    return eachline(open(filename, "r"))
  end
end

"""
This function reads a list of edges, which is generally some variant of the
form:
  i j val
or
  i j

"""
function load_edges_list(lineiter; indextype::Type = Int, valuetype::Type = Union{}, header::Bool=false, offset::Int = 1)
  if header
    hdr = collect(Base.Iterators.take(lines, 1))[1] # get the first line
  end
  ei = Vector{indextype}()
  ej = similar(ei)
  ev = Vector{valuetype}()
  for line in lineiter
    parts = split(line)
    push!(ei, parse(indextype, parts[1])+offset)
    push!(ej, parse(indextype, parts[2])+offset)
    if valuetype != Union{}
      push!(ev, parse(valuetype, parts[3]))
    end
  end
  return ei, ej, ev
end

function readSMATtoEdges(filename::AbstractString, indextype::Type, valuetype::Type)
  lines = _read_compressed(filename)
  header = collect(take(lines, 1))[1] # get the first line
  m = parse(indextype,header[1])
  n = parse(indextype,header[2])
  nz = parse(Int64,header[3])
  edges = Vector{Tuple{indextype,indextype,valuetype}}()
  for line in lines
    parts = split(line)
    push!(edges, tuple(
                  parse(indextype, parts[1])+1,
                  parse(indextype, parts[2])+1,
                  parse(valuetype, parts[3])))
  end
  return edges, m, n
end

function readSMATtoEdges(filename::AbstractString, indextype::Type)
  lines = _read_compressed(filename)
  header = collect(take(lines, 1))[1] # get the first line
  m = parse(indextype,header[1])
  n = parse(indextype,header[2])
  nz = parse(Int64,header[3])
  edges = Vector{Tuple{indextype,indextype}}()
  for line in lines
    parts = split(line)
    push!(edges, tuple(
                  parse(indextype, parts[1])+1,
                  parse(indextype, parts[2])+1))
  end
  return edges
end

export readSMAT

#=

readSMATtoEdges
readSMATtoCSR(filename, )
function readSMATtoCSR(filename::AbstractString)

=#

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
