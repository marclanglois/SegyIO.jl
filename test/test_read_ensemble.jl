# Test read_ensemble() function of SegyIO
using SegyIO

#----------------------------------------------------------------------------
function test_read_ensemble(file::String, keys::Array{String,1},
                            delimKeys::Array{String,1}, maxtrc=500;
                            verbose=false)

    file = (length(file) == 0) ?
            joinpath(SegyIO.myRoot,"data/overthrust_2D_shot_1_20.segy") : file
    keys = (length(keys) == 0) ?
            ["GroupX", "GroupY", "SourceX", "SourceY"] : keys
    delimKeys = (length(delimKeys) == 0) ?
            ["SourceX","SourceY"] : delimKeys

    s, fh = segy_open(file)

    # pre-allocate arrays.
    ns = fh.bfh.ns
    if fh.bfh.DataSampleFormat == 1
        dtype = SegyIO.IBMFloat32
    else
        dtype = Float32
    end
    headers = Array{BinaryTraceHeader,1}(undef, maxtrc)
    data = Array{dtype,2}(undef, ns, maxtrc)
#     If set to nothing, read_ensemble() will allocate for every call.
    headers = nothing
    data = nothing

    ntrc_read = 0
    ntrc_total = 0
    byte_pos = 0
    nens = 0
    prevTrace = (nothing, nothing)
    while !eof(s)
        block, byte_pos, ntrc_read, prevTrace =
            read_ensemble(s, fh, keys, delimKeys, maxtrc, byte_pos,
                          prevTrace, hdrs=headers, data=data)
        nens += 1
        ntrc_total += ntrc_read

        if verbose
        println("[test_read_ens] delim=$delimKeys, "*
                "nens=$nens, byte_pos=$byte_pos, "*
                "ntrc_read=$ntrc_read, "*
                "block: $(size(block)),$(length(block))")
        end

    end

    println("Completed after $nens ensembles, total traces $ntrc_total.")

    return nens > 0
end

@testset "read_ensemble" begin
    fname = ""
    keys = String[]
    delimkeys = String[]
    maxtrc = 500
    verbose = false # true

#    source = ("shot")
    source = ("shot", "stack")

    for src in source
        if src == "shot"
            fname = joinpath(SegyIO.myRoot,"data/overthrust_2D_shot_1_20.segy")
            keys = ["FieldRecord","GroupX","GroupY","SourceX","SourceY"]
            delimkeys = ["SourceX","SourceY"]
            maxtrc = 300
        elseif src == "stack"
            fname = joinpath(SegyIO.myRoot,"data/testdata.segy")
            keys = ["CDP","GroupX","GroupY","SourceX","SourceY"]
            delimkeys = ["SourceY"]
#            delimkeys = ["Offset"] # throws BoundsError since all offsets=0
            maxtrc = 420
        end
        @info("[read_ens] Reading $(src) ensembles from: $(fname)")
        @test test_read_ensemble(fname, keys, delimkeys, maxtrc,
                                 verbose=verbose)
#        @time test_read_ensemble(fname, keys, delimkeys, maxtrc)
    end
end

#=
test_read_ensemble("/home/marc/Downloads/cdp-3-3.sgy",
    ["CDP", "Offset", "SourceX"],
    ["CDP"], 4)
=#
#=
test_read_ensemble("/home/marc/Downloads/testdata.segy",
    ["CDP", "Offset", "SourceX", "SourceY"],
    ["SourceY"], 410)
=#
