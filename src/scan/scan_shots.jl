export scan_shots

function scan_shots!(s::IO, mem_chunk::Int, mem_trace::Int,
                    keys::Array{String,1}, file::String,
                    scan::Array{BlockScan,1}, fl_eof::Bool,
                    delimkeys::Array{String,1}=["SourceX", "SourceY"])

    # Load chunk into memory
    chunk_start = position(s)
    buf = IOBuffer(read(s, mem_chunk))
    eof(s) ? (fl_eof=true) : nothing
    buf_size = position(seekend(buf)); seekstart(buf)
    ntraces = Int(floor(buf_size/mem_trace))
    headers = Array{BinaryTraceHeader,1}(undef, ntraces)

    # Get headers from chunk
    for i in 1:ntraces
        headers[i] = read_traceheader(buf, keys, SegyIO.th_b2s)
        skip(buf, mem_trace-240)
    end

    # Get all requested header vectors
    vals = Dict{String, Array{Int32,1}}()
    for k in keys
        tmp = Int32.([getfield((headers[i]), Symbol(k)) for i in 1:ntraces])
        vals["$k"] = tmp
    end # k

    # Deliminate to find shots
    #delim1 = vals[delimkeys[1]]
    #delim2 = vals[delimkeys[2]]
    #combo = [[view(sx,i) view(sy,i)] for i in 1:ntraces] # not used.
    #combo = [[delim1[i] delim2[i]] for i in 1:ntraces]

    # Handles arbitrary length delim_hdr's.
    # Not sure about logic but this works. Why is [delim1[i] delim2[i]]
    # a column vector (1x2 Array)?
    combo = [transpose([vals[h][i] for h in delimkeys]) for i=1:ntraces ]

    part = delim_vector(combo,1)
    fl_eof ? push!(part, length(combo) + 1) : nothing

    # Summarise each shot
    for shot in 1:length(part)-1
        start_trace = part[shot]
        end_trace = part[shot + 1]-1
        start_byte = mem_trace*(start_trace-1) + chunk_start
        end_byte = mem_trace*(end_trace) + chunk_start
        summary = Dict{String, Array{Int32,1}}()

        for k in keys
            tmp = vals[k][start_trace:end_trace]
            summary["$k"] = [minimum(tmp); maximum(tmp)]
        end

        push!(scan, BlockScan(file, start_byte, end_byte, summary))
    end

    seek(s, scan[end].endbyte)
    close(buf)
    nothing
end
