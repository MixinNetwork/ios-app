import Foundation

public enum WithdrawalMemoPossibility: String {
    
    case positive
    case negative
    case possible
    
    public var isRequired: Bool {
        switch self {
        case .positive:
            return true
        case .negative, .possible:
            return false
        }
    }
    
    public init?(rawValue: String?) {
        guard let rawValue else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
    
}
