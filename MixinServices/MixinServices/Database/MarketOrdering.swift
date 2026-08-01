import Foundation

public struct MarketOrdering: Equatable {
    
    public enum Direction {
        
        case ascending
        case descending
        
        func toggled() -> Direction {
            switch self {
            case .ascending:
                    .descending
            case .descending:
                    .ascending
            }
        }
        
    }
    
    public enum Field: Equatable {
        case marketCap
        case volume
        case price
        case change(period: MarketChangePeriod)
    }
    
    public let field: Field
    public let direction: Direction
    
    public init(field: Field, direction: Direction) {
        self.field = field
        self.direction = direction
    }
    
    public func directionToggled() -> MarketOrdering {
        MarketOrdering(field: field, direction: direction.toggled())
    }
    
}
