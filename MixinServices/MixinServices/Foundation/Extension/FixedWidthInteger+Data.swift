import Foundation

enum Endianness {
    case big
    case little
}

extension FixedWidthInteger {
    
    func data(endianness: Endianness) -> Data {
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
