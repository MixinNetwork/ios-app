import Foundation

public enum OrderingDirection: Equatable, Hashable {
    
    case ascending
    case descending
    
    public var sql: String {
        switch self {
        case .ascending:
            "ASC"
        case .descending:
            "DESC"
        }
    }
    
    public func toggled() -> OrderingDirection {
        switch self {
        case .ascending:
            .descending
        case .descending:
            .ascending
        }
    }
    
}
