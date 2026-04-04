import Foundation

enum ZstdError: Error, LocalizedError {
    case notZstdData
    case unknownContentSize
    case decompressFailed(String)

    var errorDescription: String? {
        switch self {
        case .notZstdData: return "Not a Zstandard compressed file"
        case .unknownContentSize: return "Cannot determine decompressed size"
        case .decompressFailed(let msg): return "Zstd decompression failed: \(msg)"
        }
    }
}

struct ZstdDecompressor {
    static let magic: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD]

    static func decompress(_ input: Data) throws -> Data {
        guard input.count >= 4 else { throw ZstdError.notZstdData }
        let header = [input[0], input[1], input[2], input[3]]
        guard header == magic else { throw ZstdError.notZstdData }

        let contentSize = input.withUnsafeBytes { ptr -> UInt64 in
            ZSTD_getFrameContentSize(ptr.baseAddress, ptr.count)
        }

        let maxOutput: Int
        if contentSize == ZSTD_CONTENTSIZE_UNKNOWN || contentSize == ZSTD_CONTENTSIZE_ERROR {
            maxOutput = input.count * 16
        } else {
            maxOutput = Int(contentSize)
        }

        var output = Data(count: maxOutput)
        let decompressedSize = output.withUnsafeMutableBytes { outPtr in
            input.withUnsafeBytes { inPtr in
                ZSTD_decompress(outPtr.baseAddress, maxOutput, inPtr.baseAddress, inPtr.count)
            }
        }

        if ZSTD_isError(decompressedSize) != 0 {
            let errName = String(cString: ZSTD_getErrorName(decompressedSize))
            throw ZstdError.decompressFailed(errName)
        }

        output.count = decompressedSize
        return output
    }
}
