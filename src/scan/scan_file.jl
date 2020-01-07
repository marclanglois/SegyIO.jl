export scan_file

"""
    scan_file(file::String, keys::Array{String, 1}, blocksize::Int;
                chunksize::Int = 1024,
                verbosity::Int = 1)

Scan `file` for header fields in `keys`, and return a SeisCon object containing
the metadata summaries in `blocksize` groups of traces. Load `chunksize` MB of `file`
into memory at a time.

If the number of traces in `file` are not divisible by `blocksize`, the last block will
summarize the remaining traces.

`verbosity` set to 0 silences updates on the current file being scanned.

# Example

    s = scan_file('testdata.segy', ["SourceX", "SourceY"], 300)
"""
function scan_file(file::String, keys::Array{String, 1}, blocksize::Int;
                    chunksize::Int = 1024,
                    verbosity::Int = 1)

    # Put fileheader in memory and read
    verbosity==1 && println("Scanning ... $file")
    s = open(file)
    fh = read_fileheader(s)

    # Calc number of blocks
    fsize = position(seekend(s))
    mem_trace = 240 + fh.bfh.ns*4
    mem_block = blocksize*mem_trace
    ntraces_file = Int((fsize - 3600)/mem_trace)
    nblocks_file = Int(ceil(ntraces_file/blocksize))
    scan = Array{BlockScan,1}(undef, nblocks_file)
    count = 1

    # Blocks to load per chunk
    mb2b = 1024^2
    max_blocks_per_chunk = Int(floor(chunksize*mb2b/mem_block))

    # Read at most one full chunk into buffer
    seek(s, 3600)

    # For each chunk
    for c in 1:max_blocks_per_chunk:nblocks_file

        count = scan_chunk!(s, max_blocks_per_chunk, mem_block, mem_trace,
                            keys, file, scan, count)

    end # c

    return SeisCon(fh.bfh.ns, fh.bfh.DataSampleFormat, scan, fh)

end

"""
    scan_file(file::String, keys::Array{String, 1};
                chunksize::Int = 10*1024,
                verbosity::Int = 1,
                delim_keys::Array{String,1}=["SourceX","SourceY"])

Scan `file` for header fields in `keys`, and return a SeisCon object containing
the metadata summaries in single-source groups of traces. Load `chunksize` MB of `file`
into memory at a time. Trace blocks (ensembles) are defined by changes in the
values of headers in `delim_keys` (default assumes file is sorted by shot).

# Example

    s = scan_file('testdata.segy', ["SourceX", "SourceY"],
                  delim_keys=["FieldRecord"])

"""
function scan_file(file::String, keys::Array{String, 1};
                    chunksize::Int = 10*1024,
                    verbosity::Int = 1,
                    delim_keys::Array{String,1}=["SourceX","SourceY"])

    # Put fileheader in memory and read
    verbosity==1 && println("Scanning ... $file")
    s = open(file)
    fh = read_fileheader(s)

    # Add delimiter keys to scan keys if necessary
    for k in delim_keys
        k in keys ? nothing : push!(keys, k)
    end

    # Calc number of blocks
    fsize = filesize(file)
    mem_trace = 240 + fh.bfh.ns*4
    ntraces_file = Int((fsize - 3600)/mem_trace)
    scan = Array{BlockScan,1}(undef, 0)
    seek(s, 3600)
    traces_per_chunk = Int(floor(chunksize*1024^2/mem_trace))

    mem_chunk = traces_per_chunk*mem_trace
    fl_eof = false
    while !eof(s)
        scan_shots!(s, mem_chunk, mem_trace, keys, file, scan, fl_eof,
                    delim_keys)
    end

    close(s)
    
    verbosity== 1 &&
        println("[scan_file] Creating SeisCon, ns=$(fh.bfh.ns), "*
                "dt=$(fh.bfh.dt)")

    return SeisCon(fh.bfh.ns, fh.bfh.DataSampleFormat, scan, fh)

end
