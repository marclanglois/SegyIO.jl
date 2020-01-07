import Base.size, Base.length

export SeisBlock, set_header!, set_traceheader!, set_fileheader!

mutable struct SeisBlock{DT<:Union{IBMFloat32, Float32}}
    fileheader::FileHeader
    traceheaders::AbstractArray{BinaryTraceHeader, 1}
    data::AbstractArray{DT,2}
end

size(block::SeisBlock) = size(block.data)
length(block::SeisBlock) = length(block.traceheaders)

function SeisBlock(data::Array{DT,2}) where {DT<:Union{Float32, IBMFloat32}}

    # Construct FileHeader
    ns, ntraces = size(data)
    fh = FileHeader()
    fh.bfh.ns = ns
    DT==Float32 ? fh.bfh.DataSampleFormat=5 : fh.bfh.DataSampleFormat=1

    return SeisBlock(data, fh)
end

#function SeisBlock(data::Array{DT,2}, fh::FileHeader) where {DT<:Union{Float32, IBMFloat32}}

function SeisBlock(data::Array{DT,2} where {DT<:Union{Float32, IBMFloat32}},
                   fh::FileHeader)

    ns, ntraces = size(data)

    # TODO: Override values in fh.bfh to match data?
#    fh.bfh.ns = ns
#    DT==Float32 ? fh.bfh.DataSampleFormat=5 : fh.bfh.DataSampleFormat=1

    # Construct TraceHeaders
    traceheaders = [BinaryTraceHeader() for i in 1:ntraces]
    set_traceheader!(traceheaders, :ns, ns*ones(Int16, ntraces))

    # Construct Block
    block = SeisBlock(fh, traceheaders, data)

    return block
end
