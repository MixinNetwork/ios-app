import Foundation
import Foundation

struct DerivationPath {
    
    enum ParseError: Error {
        case invalidPrefix
        case invalidComponent(Substring)
    }
    
    let string: String
    let indices: [ExtendedKey.Index]
    
    init(string: String) throws {
        guard string.starts(with: "m/") else {
            throw ParseError.invalidPrefix
        }
        let indices: [ExtendedKey.Index] = try string
            .dropFirst(2) // Drop "m/"
            .split(separator: "/")
            .map { component in
                if component.last == "'" {
                    let value = component.dropLast()
                    if let value = UInt32(value)  {
                        return .hardened(value)
                    } else {
                        throw ParseError.invalidComponent(component)
                    }
                } else {
                    if let value = UInt32(component)  {
                        return .normal(value)
                    } else {
                        throw ParseError.invalidComponent(component)
                    }
                }
            }
        self.string = string
        self.indices = indices
    }
    
}

extension DerivationPath {
    
    static func bitcoin<Integer: FixedWidthInteger>(index: Integer) throws -> DerivationPath {
        try DerivationPath(string: "m/84'/0'/0'/0/\(index)")
    }
    
    static func evm<Integer: FixedWidthInteger>(index: Integer) throws -> DerivationPath {
        try DerivationPath(string: "m/44'/60'/0'/0/\(index)")
    }
    
    static func evmPathRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: #"^m\/44'\/60'\/0'\/0\/(\d+)$"#, options: [])
    }
    
    static func solana<Integer: FixedWidthInteger>(index: Integer) throws -> DerivationPath {
        try DerivationPath(string: "m/44'/501'/\(index)'/0'")
    }
    
    static func solanaPathRegex() throws -> NSRegularExpression {
        try NSRegularExpression(pattern: #"^m\/44'\/501'\/(\d+)'\/0'$"#, options: [])
    }
    
}
