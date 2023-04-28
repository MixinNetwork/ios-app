import Foundation
import zlib

struct CRC32 {
    
    private var crc: uLong = crc32(0, nil, 0)
    
    mutating func update(data: Data) {
        crc = data.withUnsafeBytes { buffer in
            crc32_z(crc, buffer.baseAddress, buffer.count)
        }
    }
    
    func finalize() -> UInt64 {
        UInt64(crc)
    }
    
}

extension CRC32 {
    
    static func checksum(data: Data) -> UInt64 {
        data.withUnsafeBytes { buffer in
            UInt64(crc32_z(0, buffer.baseAddress, buffer.count))
        }
    }
    
}
