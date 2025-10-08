import Foundation
import MixinServices

struct TokenComparator<Token: ValuableToken>: SortComparator {
    
    var order: SortOrder = .forward
    
    private let lowercasedKeyword: String
    
    init(keyword: String) {
        self.lowercasedKeyword = keyword.lowercased()
    }
    
    func compare(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        let leftDeterminant = determinant(item: lhs)
        let rightDeterminant = determinant(item: rhs)
        let forwardResult: ComparisonResult = if leftDeterminant == rightDeterminant {
            lhs.name.compare(rhs.name)
        } else if leftDeterminant < rightDeterminant {
            .orderedDescending
        } else {
            .orderedAscending
        }
        return switch order {
        case .forward:
             forwardResult
        case .reverse:
            switch forwardResult {
            case .orderedAscending:
                    .orderedDescending
            case .orderedDescending:
                    .orderedAscending
            case .orderedSame:
                    .orderedSame
            }
        }
    }
    
    func determinant(item: Token) -> (Int, Decimal, Decimal) {
        let lowercasedSymbol = item.symbol.lowercased()
        let symbolPriority = if lowercasedSymbol == lowercasedKeyword {
            3
        } else if lowercasedSymbol.hasPrefix(lowercasedKeyword) {
            2
        } else if lowercasedSymbol.contains(lowercasedKeyword) {
            1
        } else {
            0
        }
        return (
            symbolPriority,
            item.decimalBalance * item.decimalUSDPrice,
            item.decimalBalance,
        )
    }
    
}
