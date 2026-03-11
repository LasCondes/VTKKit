import Compression
import Foundation

public struct VTKCompression: Sendable, Equatable, Codable {
    public enum Algorithm: String, Sendable, Codable, CaseIterable {
        case zlib = "vtkZLibDataCompressor"
        case lz4 = "vtkLZ4DataCompressor"
        case lzma = "vtkLZMADataCompressor"

        var compressionAlgorithm: compression_algorithm {
            switch self {
            case .zlib:
                COMPRESSION_ZLIB
            case .lz4:
                COMPRESSION_LZ4
            case .lzma:
                COMPRESSION_LZMA
            }
        }
    }

    public var algorithm: Algorithm
    public var blockSize: Int

    public init(algorithm: Algorithm, blockSize: Int = 32 * 1024) {
        self.algorithm = algorithm
        self.blockSize = blockSize
    }

    public static let zlib = VTKCompression(algorithm: .zlib)
    public static let lz4 = VTKCompression(algorithm: .lz4)
    public static let lzma = VTKCompression(algorithm: .lzma)

    var vtkClassName: String {
        algorithm.rawValue
    }

    func encodedPayload(
        for payload: Data,
        headerType: BinaryDataHeaderType,
        byteOrder: ByteOrder,
        arrayName: String
    ) throws -> Data {
        guard blockSize > 0 else {
            throw VTKWriter.Error.invalidCompressionConfiguration(
                reason: "blockSize must be greater than zero."
            )
        }

        let chunks = payload.chunked(maximumBlockSize: blockSize)
        let compressedChunks = try chunks.map { try compress(chunk: $0, arrayName: arrayName) }
        let lastBlockSize = chunks.last?.count ?? 0

        var data = Data()
        try headerType.appendHeaderValue(chunks.count, into: &data, byteOrder: byteOrder, arrayName: arrayName)
        try headerType.appendHeaderValue(blockSize, into: &data, byteOrder: byteOrder, arrayName: arrayName)
        try headerType.appendHeaderValue(lastBlockSize, into: &data, byteOrder: byteOrder, arrayName: arrayName)

        for chunk in compressedChunks {
            try headerType.appendHeaderValue(chunk.count, into: &data, byteOrder: byteOrder, arrayName: arrayName)
        }

        for chunk in compressedChunks {
            data.append(chunk)
        }

        return data
    }

    private func compress(chunk: Data, arrayName: String) throws -> Data {
        guard chunk.isEmpty == false else {
            return Data()
        }

        let destinationBufferSize = Swift.max(blockSize, 4 * 1024)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { destinationBuffer.deallocate() }

        return try chunk.withUnsafeBytes { sourceBuffer in
            let sourceBytes = sourceBuffer.bindMemory(to: UInt8.self)
            var stream = compression_stream(
                dst_ptr: destinationBuffer,
                dst_size: destinationBufferSize,
                src_ptr: sourceBytes.baseAddress!,
                src_size: sourceBytes.count,
                state: nil
            )
            var status = compression_stream_init(
                &stream,
                COMPRESSION_STREAM_ENCODE,
                algorithm.compressionAlgorithm
            )
            guard status != COMPRESSION_STATUS_ERROR else {
                throw VTKWriter.Error.compressionFailed(arrayName: arrayName, algorithm: algorithm.rawValue)
            }
            defer { compression_stream_destroy(&stream) }

            var output = Data()
            repeat {
                stream.dst_ptr = destinationBuffer
                stream.dst_size = destinationBufferSize

                status = compression_stream_process(
                    &stream,
                    Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                )
                guard status != COMPRESSION_STATUS_ERROR else {
                    throw VTKWriter.Error.compressionFailed(arrayName: arrayName, algorithm: algorithm.rawValue)
                }

                let producedByteCount = destinationBufferSize - stream.dst_size
                output.append(destinationBuffer, count: producedByteCount)
            } while status == COMPRESSION_STATUS_OK

            return output
        }
    }
}

public extension DataArrayBinaryStorage {
    init<Scalar: VTKScalarValue>(
        values: [Scalar],
        byteOrder: ByteOrder = .native
    ) {
        self.init(
            data: Data(copyingScalars: values),
            valueCount: values.count,
            byteOrder: byteOrder
        )
    }

    init<Scalar: VTKScalarValue>(
        contiguousValues: ContiguousArray<Scalar>,
        byteOrder: ByteOrder = .native
    ) {
        self.init(
            data: contiguousValues.withUnsafeBufferPointer { Data(copyingScalars: $0) },
            valueCount: contiguousValues.count,
            byteOrder: byteOrder
        )
    }

    init<Scalar: VTKScalarValue>(
        buffer: UnsafeBufferPointer<Scalar>,
        byteOrder: ByteOrder = .native
    ) {
        self.init(
            data: Data(copyingScalars: buffer),
            valueCount: buffer.count,
            byteOrder: byteOrder
        )
    }
}

private extension Data {
    init<Scalar>(copyingScalars values: [Scalar]) {
        self = values.withUnsafeBufferPointer { Data(copyingScalars: $0) }
    }

    init<Scalar>(copyingScalars buffer: UnsafeBufferPointer<Scalar>) {
        self = Data(buffer: buffer)
    }

    func chunked(maximumBlockSize: Int) -> [Data] {
        guard isEmpty == false else {
            return []
        }

        var chunks: [Data] = []
        chunks.reserveCapacity((count + maximumBlockSize - 1) / maximumBlockSize)

        var offset = startIndex
        while offset < endIndex {
            let upperBound = index(offset, offsetBy: maximumBlockSize, limitedBy: endIndex) ?? endIndex
            chunks.append(self[offset..<upperBound])
            offset = upperBound
        }

        return chunks
    }
}
