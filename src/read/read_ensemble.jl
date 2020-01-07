using SegyIO; const SIO = SegyIO
export segy_open, read_ensemble

const SEGY_DATA_TYPES = Dict(1=>SIO.IBMFloat32, 5=>Float32)
const TRACE_HDR_BYTE2SAMPLE = SIO.th_byte2sample()

#------------------------------------------------------------------------------
# Methods added by Marc.
"""
segy_open(file::String; buffer::Bool = true, warn_user::Bool = true)

Open a SEGY file and return the stream and the file header.
"""
function segy_open(file::String; buffer::Bool = true, warn_user::Bool = true)

    s = fh = nothing

    if buffer
        s = IOBuffer(read(open(file)))
    else
        s = open(file)
    end

    # Read File Header
    fh = read_fileheader(s)

    # Check fixed length trace flag
    (fh.bfh.FixedLengthTraceFlag!=1 & warn_user) &&
        @warn "Fixed length trace flag set in stream: $s"

    # Check datatype of file
    if fh.bfh.DataSampleFormat in keys(SEGY_DATA_TYPES)
        datatype = SEGY_DATA_TYPES[fh.bfh.DataSampleFormat]
    else
        @error "Data type not supported ($(fh.bfh.DataSampleFormat))"
    end

    @info("[segy_open] bfh: ns=$(fh.bfh.ns), dt=$(fh.bfh.dt), "*
            "fmt=$(fh.bfh.DataSampleFormat) ($(datatype))")

    return s, fh
end

"""
read_ensemble(s)

Read a SEGY ensemble from stream 's'. Ensemble are delimited by a change in
the values of the headers in `delimkeys`.
"""
function read_ensemble(s::IO, fh::SIO.FileHeader,
        keys::Array{String}, delimkeys::Array{String},
        maxTraces::Int, startbyte::Int, prevTrace::Tuple;
        hdrs::Union{Nothing,Array{Number,1}}=nothing,
        data::Union{Nothing,Array{Number,2}}=nothing,
        warn_user::Bool=true)

    datatype = SEGY_DATA_TYPES[fh.bfh.DataSampleFormat]

    # Make sure all delimkeys are in keys.
    # TODO: Needed for every read?
    for k in delimkeys
        in(k, keys) ? nothing : push!(keys, k)
    end

    # Move to start of trace, skipping EBCDIC header if first trace.
    startbyte = max(startbyte, 3600)
    seek(s, startbyte)

    trc_length = get_trace_length(Int(fh.bfh.ns), nbytes=sizeof(datatype))
    @debug("[read_ens] startbyte=$(startbyte), trc_length=$trc_length")

    # Allocate arrays if required.
    if hdrs == nothing
        @debug("[read_ens] allocating hdrs, ntrc=$(maxTraces).")
        hdrs = Array{BinaryTraceHeader,1}(undef, maxTraces)
    end
    if data == nothing
        @debug("[read_ens] allocating data, ns=$(fh.bfh.ns),ntrc=$(maxTraces).")
        data = Array{datatype,2}(undef, fh.bfh.ns, maxTraces)
    end

    # Read first trace in ensemble.
    SIO.read_trace!(s, fh.bfh, datatype, hdrs, data, 1, keys,
                    TRACE_HDR_BYTE2SAMPLE)

    # Initialize array of values of delimiter headers.
    prevVals = Int[]
    for k in delimkeys
        push!(prevVals, getfield(hdrs[1], Symbol(k)))
    end

    prevTrace = (prevTrace[1] == nothing) ? prevTrace = ([], []) : prevTrace

    # Read traces until delimiter headers change, or max number of traces is
    # reached.
    # TODO: Save last trace read to use as first trace in next ensemble?
    itrc = 2; ntrcEns = itrc

    while itrc <= maxTraces
        try
            SIO.read_trace!(s, fh.bfh, datatype, hdrs, data, itrc,
                            keys, TRACE_HDR_BYTE2SAMPLE)
        catch err
            if typeof(err) <: EOFError
                @debug "[read_ens] Read EOF on input stream."
                ntrcEns = itrc - 1
                break
            else
                @error "[read_ensemble] Error reading trace from input stream."
                throw(err)
            end
        end

        if is_header_changed(hdrs[itrc], delimkeys, prevVals)
            @debug("[read_ens] hdr change at trace $itrc - exiting loop")
            ntrcEns = itrc - 1
#            prevTrace = (hdrs[itrc], data[itrc])
            break
        elseif itrc == maxTraces
            @error("[read_ens] Max traces: ($maxTraces) read for ensemble "*
                   "before change in delim keys: $(delimkeys)")
            throw(BoundsError)
        end
        @debug("[read_ens] Read input trace $itrc, "*
               "cdp=$cdp, offset=$offset, byte_pos=$(position(s))")
        itrc += 1
        ntrcEns = itrc
    end

    # Set position of the next ensemble by subtracting the length of the
    # last trace read. Not needed if ntrcEns == maxTraces.
    byte_pos = position(s)
    if ntrcEns < maxTraces && !eof(s)
      byte_pos -= trc_length
      @debug("[read_ens] backing up one trace to byte_pos=$(byte_pos).")
    end
    @debug("[read_ensemble] Ensemble completed, num traces $(ntrcEns), "*
           "byte_pos=$byte_pos")

    return SIO.SeisBlock(fh, hdrs, data), byte_pos, ntrcEns, prevTrace
end

"""
Return true if the delimiter keys in hdr are different from lastVals.
"""
function is_header_changed(hdr::SIO.BinaryTraceHeader,
                           delimkeys::Array{String,1},
                           lastVals::Array{Int,1})
    changed = false
    for (i, k) in enumerate(delimkeys)
        if (lastVals[i] != getfield(hdr, Symbol(k))) return true end
    end
    return changed
end

"""
Functions to return trace length in bytes and number of traces
from start/end bytes.
"""
function get_trace_length(ns::Int; nbytes::Int=4, hdrlen::Int=240)
    return hdrlen + (ns*nbytes)
end
function get_num_traces(startbyte::Int, endbyte::Int, ns::Int;
                        hdrlen::Int=240, nbytes::Int=4)
    return (endbyte - startbyte) / get_trace_length(ns, nbytes)
end
