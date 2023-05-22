import Foundation

public enum DeviceTransferPlatform: RawRepresentable, Codable {
    
    case iOS
    case other(String)
    
    public var rawValue: String {
        switch self {
        case .iOS:
            return "iOS"
        case .other(let value):
            return value
        }
    }
    
    public init(rawValue: String) {
        if rawValue == "iOS" {
            self = .iOS
        } else {
            self = .other(rawValue)
        }
    }
    
}
