import Foundation

public struct SemanticVersion: InstanceInitializable {
    
    public let major: Int
    public let minor: Int
    public let patch: Int
    
    public init?(string: String) {
        let components = string.components(separatedBy: ".")
        guard
            components.count == 3,
            let major = Int(components[0]),
            let minor = Int(components[1]),
            let patch = Int(components[2])
        else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
}

extension SemanticVersion: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
    
}

extension SemanticVersion: Comparable {
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.major < rhs.major || lhs.minor < rhs.minor || lhs.patch < rhs.patch
    }
    
    public static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.major > rhs.major || lhs.minor > rhs.minor || lhs.patch > rhs.patch
    }
    
}

extension SemanticVersion: Codable {
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let version = SemanticVersion(string: value) {
            self.init(instance: version)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid string")
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(major).\(minor).\(patch)")
    }
    
}
