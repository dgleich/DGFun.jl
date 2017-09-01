"""
Read a text file consistent entirely of floating point numbers separated
by single spaces or newlines.

I saw that this was about 1.5-2x faster than CSV.jl, which was the fastest
of the existing read methods.
"""



@inline mytryparse(::Type{Float64}, s::Vector{UInt8}, pos::Int64, len::Int64) =
            ccall(:jl_try_substrtod, Nullable{Float64}, (Ptr{UInt8},Csize_t,Csize_t), s, pos, len)

@inline function myparse(::Type{Float64}, s::Vector{UInt8}, pos::Int64, last::Int64)
    result = mytryparse(Float64, s, pos-1, last-pos+1)
    if isnull(result)
        throw(ArgumentError("cannot parse $(repr(s)) as $Float64"))
    end
    if VERSION < v"0.6"
      # when introduced, the function of unsafe_get is
      # unsafe_get(x::Nullable) = x.value
      # unsafe_get(x) = x
      return result.value
    else
      return unsafe_get(result)
    end
end


@inline function myparse(::Type{Int32}, s::Vector{UInt8}, pos::Int64, last::Int64)
    val = myparse(Float64, s, pos, last)
    return convert(Int32, val)
end

"""
Find the next space in the buffer a, starting the search at position = pos
and continuing until we find a space or hit len. If we can't find a space, 
return -1, otherwise, return the index of the space.
"""
@inline function next_space(a::Vector{UInt8}, pos, len)
    @inbounds for i = pos:len
        if a[i] == UInt8(' ') || a[i] == UInt8('\n') || a[i] == UInt8('\t')
            return i
        end
    end
    return -1
end

@inline function next_non_space(a::Vector{UInt8}, pos, len)
    @inbounds for i = pos:len
        if a[i] != UInt8(' ') && a[i] != UInt8('\n') && a[i] != UInt8('\t')
            return i
        end
    end
    return -1
end

@inline function next_space_with_leading(a::Vector{UInt8}, pos, len)
    skip = next_non_space(a, pos, len)
    skip != -1 && return next_space(a, skip, len)
    return skip
end

@inline function all_spaces(a::Vector{UInt8}, pos, len)
    @inbounds for i = pos:len
        if a[i] != UInt8(' ') && a[i] != UInt8('\n') && a[i] != UInt8('\t')
            return false
        end
    end
    return true
end

mydebug = false



function tseq2(io::IO, a; maxbuf::Int=2^10, ntok::Int=-1)
    buf = Vector{UInt8}(maxbuf) # 64k bytes
    curtok = 0
    curbuf = 1
    
    tokinc = 1
    if ntok == -1
        tokinc = 0
        ntok = 1
    end
        
    while !eof(io) && curtok < ntok
        x = read(io, UInt8)
        if curbuf > 1
            # then we are processing a token
            if x == UInt8(' ') || x == UInt8('\n') || x == UInt8('\t')
                # there is a token from buf[1:curbuf]
                #@show "token", String(buf[1:curbuf-1])
                push!(a, myparse(Float64, buf, 1, curbuf-1))
                curtok += tokinc
                curbuf = 1
            elseif curbuf > maxbuf
                throw(ArgumentError("current token exceeded maxbuf=$(maxbuf)"))
            else
                buf[curbuf] = x
                curbuf += 1
            end
        else
            # otherwise we are handling spaces
            if x == UInt8(' ') || x == UInt8('\n') || x == UInt8('\t')
                continue
            else
                buf[curbuf] = x
                curbuf += 1 # we are in a token now!
            end
        end
    end
    if eof(io) && curtok < ntok && curbuf > 1
        # @show "token", String(buf[1:curbuf-1])
        push!(a, myparse(Float64, buf, 1, curbuf-1))
    end
    return a
end

function tseq(io::IO, a; maxbuf::Int=2^10)
    buf = Vector{UInt8}(maxbuf) # 64k bytes
    buf2 = Vector{UInt8}(maxbuf) # 64k bytes
    eof = false
    nb = readbytes!(io, buf)
    if nb == 0
        return a # just return
    end
    (nb < maxbuf) && (eof = true)

    curspace = next_non_space(buf, 1, nb)

    @inbounds while nb >= 0 && curspace >= 0
        nextspace = next_space_with_leading(buf, curspace+1, nb)
        if nextspace >= 0
            mydebug && @show "parsing", String(buf[curspace:nextspace])
            push!(a, myparse(Float64, buf, curspace, nextspace))
        elseif curspace == 1 && eof == true
            push!(a, myparse(Float64, buf, curspace, nb))
            # We are at eof and just processed the last of the buffer
        elseif curspace == 1
            @show curspace, nextspace
            throw(ArgumentError("current value exceeded maxbuf=$(maxbuf)"))
        else
            # we didn't see a space, that means we need to read more buffer
            # move things to beginning
            mydebug && print("Refilling: ", replace(String(buf),"\n","@"), " ", curspace, " ", String(buf[curspace:nb]), "\n")
            copy!(buf, 1, buf, curspace, nb - curspace + 1)
            #print("     Move: ", replace(String(buf),"\n","@"), "\n")
            bufstart = nb - curspace + 2
            #buffree = maxbuf - bufstart + 1
            curspace = 1

            # Try reading
            #nread = readbytes!(io, @view(buf[bufstart:end]))
            nread = readbytes!(io, buf2, maxbuf-bufstart+1)
            copy!(buf, bufstart, buf2, 1, maxbuf-bufstart+1)
            (nread < maxbuf-bufstart+1) && (eof = true)

            mydebug && print("   Reload: ", replace(String(buf),"\n","@"), "\n")

            mydebug && @show nread

            if nread == 0
                # We couldn't read any more, that means we are at the end!
                #print("    Final: ", replace(String(buf),"\n","@"), "\n")
                mydebug && @show "final", String(buf[curspace:bufstart-1])
                if bufstart > 2 && !all_spaces(buf, curspace, bufstart-1)
                    push!(a, myparse(Float64, buf, curspace, bufstart-1))
                    return a
                end
            else
                nb = bufstart + nread - 1
                mydebug && @show String(buf[curspace:nb])
                continue
            end

        end
        curspace = nextspace
    end
    return a
end

function read_file_to_float64_array(filename::AbstractString)
	a = zeros(0)
	open(filename, "r") do fh
		return tseq(fh, a)
	end
end


function readarrayt(io; kwargs...)
    line = readline(io) # read the first line
    a = zeros(0) # allocate the output 
    tseq(IOBuffer(line), a; kwargs...) # parse the first line
    ncols = length(a) # this is the number of columns
    tseq(io, a; kwargs...) # read the rest of the array
    nrows, nrem = divrem(length(a),ncols)
    if nrem != 0
        throw(ArgumentError("first line of file had $(ncols) entries," *
            " but file has $(length(a)) for $(nrows) rows and $(nrem) left"))
    else
        return reshape(a, ncols, nrows)
    end
end
readarray(io; kwargs...) = readarrayt(io; kwargs...)'

#=
function read_number_stream(io, record::Tuple{Type}, nrec; all=true)
    
end
=#