import Foundation

public enum Wallet {
    
    public enum Kind {
        case privacy
        case classic
    }
    
    case privacy
    case classic(id: String)
    
}

extension Wallet: RawRepresentable {
    
    public init?(rawValue: String) {
        switch rawValue.first {
        case "p":
            self = .privacy
        case "c":
            let id = String(rawValue.dropFirst())
            self = .classic(id: id)
        default:
            return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case .privacy:
            "p"
        case .classic(let id):
            "c" + id
        }
    }
    
}
