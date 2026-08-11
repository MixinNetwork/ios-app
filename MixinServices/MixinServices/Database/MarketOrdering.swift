import Foundation

public struct MarketOrdering: Equatable, Hashable {
    
    public enum Direction: Equatable, Hashable {
        
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
    
    public enum Field: Equatable, Hashable {
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

extension MarketOrdering: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        var description = switch field {
        case .marketCap:
            "MarketCap"
        case .volume:
            "Volume"
        case .price:
            "Price"
        case .change(let period):
            switch period {
            case .twentyFourHours:
                "24H%"
            case .sevenDays:
                "7D%"
            }
        }
        switch direction {
        case .ascending:
            description += " ↑"
        case .descending:
            description += " ↓"
        }
        return description
    }
    
}
