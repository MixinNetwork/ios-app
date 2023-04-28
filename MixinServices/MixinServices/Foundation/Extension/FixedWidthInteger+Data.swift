import Foundation

public enum Endianness {
    case big
    case little
}

extension FixedWidthInteger {
    
    public init(data: Data, endianess: Endianness) {
        var raw: Self = 0
        withUnsafeMutableBytes(of: &raw) { raw in
            data.withUnsafeBytes { data in
                data.copyBytes(to: raw)
            }
        }
        switch endianess {
        case .big:
            self = Self(bigEndian: raw)
        case .little:
            self = Self(littleEndian: raw)
        }
    }
    
    public func data(endianness: Endianness) -> Data {
        let value: Self
        switch endianness {
        case .big:
            value = bigEndian
        case .little:
            value = littleEndian
        }
        return withUnsafeBytes(of: value) { buffer in
            Data(buffer)
        }
    }
    
}
