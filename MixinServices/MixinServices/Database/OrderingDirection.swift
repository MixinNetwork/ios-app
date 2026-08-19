import Foundation

public enum OrderingDirection: Equatable, Hashable {
    
    case ascending
    case descending
    
    public func toggled() -> OrderingDirection {
        switch self {
        case .ascending:
            .descending
        case .descending:
            .ascending
        }
    }
    
}
