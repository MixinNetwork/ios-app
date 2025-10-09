import Foundation
import MixinServices

protocol ComparableToken: ValuableToken {
    var chainName: String? { get }
}

extension MixinTokenItem: ComparableToken {
    
    var chainName: String? {
        chain?.name
    }
    
}

extension Web3TokenItem: ComparableToken {
    
    var chainName: String? {
        chain?.name
    }
    
}

extension BalancedSwapToken: ComparableToken {
    
    var chainName: String? {
        chain.name
    }
    
}

struct TokenComparator<Token: ComparableToken>: SortComparator {
    
    var order: SortOrder = .forward
    
    private let lowercasedKeyword: String
    
    init(keyword: String) {
        self.lowercasedKeyword = keyword.lowercased()
    }
    
    func compare(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        let leftDeterminant = determinant(item: lhs)
        let rightDeterminant = determinant(item: rhs)
        
        let forwardResult: ComparisonResult
        if leftDeterminant == rightDeterminant {
            let nameComparisonResult = lhs.name.compare(rhs.name)
            switch nameComparisonResult {
            case .orderedDescending, .orderedAscending:
                forwardResult = nameComparisonResult
            case .orderedSame:
                let left = lhs.chainName ?? ""
                let right = rhs.chainName ?? ""
                forwardResult = left.compare(right)
            }
        } else if leftDeterminant < rightDeterminant {
            forwardResult = .orderedDescending
        } else {
            forwardResult = .orderedAscending
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
