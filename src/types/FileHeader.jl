export FileHeader

struct FileHeader
    th::String
    bfh::BinaryFileHeader
end

function show(io::IO, fh::FileHeader)
    show(fh.bfh)
end

FileHeader() = FileHeader(" "^3200, BinaryFileHeader())
FileHeader(fh::FileHeader) = FileHeader(fh.th, BinaryFileHeader(fh.bfh))
FileHeader(bfh::BinaryFileHeader) =
    FileHeader(" "^3200, BinaryFileHeader(fh.bfh))
