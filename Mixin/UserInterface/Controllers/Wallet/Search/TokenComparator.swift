import Foundation
import MixinServices

extension BalancedSwapToken: ComparableToken {
    
    var chainName: String? {
        chain.name
    }
    
}

struct TokenComparator<Token: ComparableToken>: SortComparator {
    
    var order: SortOrder = .forward
    
    private let ordering: TokenOrdering
    
    init(keyword: String?) {
        self.ordering = TokenOrdering(keyword: keyword)
    }
    
    func compare(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        let result = ordering.compare(lhs, rhs)
        switch order {
        case .forward:
            return result
        case .reverse:
            return switch result {
            case .orderedAscending:
                    .orderedDescending
            case .orderedDescending:
                    .orderedAscending
            case .orderedSame:
                    .orderedSame
            }
        }
    }
    
}
