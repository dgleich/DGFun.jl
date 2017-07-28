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


function tseq(io::IO, a; maxbuf::Int=2^10)
    #maxbuf = 2^10 # 64k bytes
    buf = Vector{UInt8}(maxbuf) # 64k bytes
    buf2 = Vector{UInt8}(maxbuf) # 64k bytes
    nb = readbytes!(io, buf)
    if nb == 0
        return a # just return
    end

    curspace = next_non_space(buf, 1, nb)

    @inbounds while nb >= 0 && curspace >= 0
        nextspace = next_space(buf, curspace+1, nb)
        if nextspace >= 0
            #@show "parsing", String(buf[curspace:nextspace])
            push!(a, myparse(Float64, buf, curspace, nextspace))
        else
            # we didn't see a space, that means we need to read more buffer
            # move things to beginning
            #print("Refilling: ", replace(String(buf),"\n","@"), " ", curspace, " ", String(buf[curspace:nb]), "\n")
            copy!(buf, 1, buf, curspace, nb - curspace + 1)
            #print("     Move: ", replace(String(buf),"\n","@"), "\n")
            bufstart = nb - curspace + 2
            #buffree = maxbuf - bufstart + 1
            curspace = 1

            # Try reading
            #nread = readbytes!(io, @view(buf[bufstart:end]))
            nread = readbytes!(io, buf2, maxbuf-bufstart+1)
            copy!(buf, bufstart, buf2, 1, maxbuf-bufstart+1)

            #print("   Reload: ", replace(String(buf),"\n","@"), "\n")

            #@show nread

            if nread == 0
                # We couldn't read any more, that means we are at the end!
                #print("    Final: ", replace(String(buf),"\n","@"), "\n")
                #@show String(buf[curspace:bufstart-1])
                if bufstart > 2
                    # then there is stuff to process!
                    push!(a, myparse(Float64, buf, curspace, bufstart-1))
                    return a
                end

            else
                nb = bufstart + nread - 1
                #@show String(buf[curspace:nb])
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
