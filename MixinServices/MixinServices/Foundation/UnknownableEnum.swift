import Foundation

public enum UnknownableEnum<T: RawRepresentable>: RawRepresentable {
    
    case known(T)
    case unknown(T.RawValue)
    
    public var knownCase: T? {
        switch self {
        case .known(let value):
            value
        case .unknown:
            nil
        }
    }
    
    public init(rawValue: T.RawValue) {
        if let value = T(rawValue: rawValue) {
            self = .known(value)
        } else {
            self = .unknown(rawValue)
        }
    }
    
    public var rawValue: T.RawValue {
        switch self {
        case .known(let value):
            value.rawValue
        case .unknown(let rawValue):
            rawValue
        }
    }
    
}

extension UnknownableEnum: Decodable where T.RawValue: Decodable {
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(T.RawValue.self)
        self.init(rawValue: rawValue)
    }
    
}

extension UnknownableEnum: Encodable where T.RawValue: Encodable {
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
}
