import Foundation
import MixinServices

struct DeviceTransferHeader {
    
    enum ContentType: UInt8 {
        case command = 0x01
        case message = 0x02
        case file = 0x03
    }
    
    let type: ContentType
    let length: Int32
    
    init(type: ContentType, length: Int32) {
        self.type = type
        self.length = length
    }
    
}

extension DeviceTransferHeader {
    
    static let encodedSize = 5
    
    func encoded() -> Data {
        var data = Data(count: Self.encodedSize)
        data[data.startIndex] = type.rawValue
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: length.bigEndian, toByteOffset: 1, as: Int32.self)
        }
        return data
    }
    
}

extension DeviceTransferHeader: RawBufferInitializable {
    
    static var bufferCount: Int {
        Self.encodedSize
    }
    
    init?(_ buffer: UnsafeMutableRawBufferPointer) {
        assert(buffer.count >= Self.bufferCount)
        guard let type = ContentType(rawValue: buffer[buffer.startIndex]) else {
            return nil
        }
        let length = buffer.loadUnaligned(fromByteOffset: 1, as: Int32.self)
        self.type = type
        self.length = Int32(bigEndian: length)
    }
    
}
