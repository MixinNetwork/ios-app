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
    
    private let lowercasedKeyword: String?
    
    init(keyword: String?) {
        self.lowercasedKeyword = keyword?.lowercased()
    }
    
    func compare(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        let firstStepResult: ComparisonResult
        if let lowercasedKeyword {
            let leftDeterminant = determinant(item: lhs, lowercasedKeyword: lowercasedKeyword)
            let rightDeterminant = determinant(item: rhs, lowercasedKeyword: lowercasedKeyword)
            if leftDeterminant == rightDeterminant {
                firstStepResult = .orderedSame
            } else if leftDeterminant < rightDeterminant {
                firstStepResult = .orderedDescending
            } else {
                firstStepResult = .orderedAscending
            }
        } else {
            let leftDeterminant = determinant(item: lhs)
            let rightDeterminant = determinant(item: rhs)
            if leftDeterminant == rightDeterminant {
                firstStepResult = .orderedSame
            } else if leftDeterminant < rightDeterminant {
                firstStepResult = .orderedDescending
            } else {
                firstStepResult = .orderedAscending
            }
        }
        
        let forwardResult: ComparisonResult
        switch firstStepResult {
        case .orderedAscending:
            forwardResult = .orderedAscending
        case .orderedDescending:
            forwardResult = .orderedDescending
        case .orderedSame:
            let nameComparisonResult = lhs.name.compare(rhs.name)
            switch nameComparisonResult {
            case .orderedDescending, .orderedAscending:
                forwardResult = nameComparisonResult
            case .orderedSame:
                let left = lhs.chainName ?? ""
                let right = rhs.chainName ?? ""
                forwardResult = left.compare(right)
            }
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
    
    func determinant(item: Token, lowercasedKeyword: String) -> (Int, Decimal, Decimal, Int) {
        let lowercasedSymbol = item.symbol.lowercased()
        let missingIconURL = "https://images.mixin.one/yH_I5b0GiV2zDmvrXRyr3bK5xusjfy5q7FX3lw3mM2Ryx4Dfuj6Xcw8SHNRnDKm7ZVE3_LvpKlLdcLrlFQUBhds=s128"
        let symbolPriority = if lowercasedSymbol == lowercasedKeyword {
            3
        } else if lowercasedSymbol.hasPrefix(lowercasedKeyword) {
            2
        } else if lowercasedSymbol.contains(lowercasedKeyword) {
            1
        } else {
            0
        }
        let iconPriority = item.iconURL == missingIconURL ? 0 : 1
        return (
            symbolPriority,
            item.decimalBalance * item.decimalUSDPrice,
            item.decimalBalance,
            iconPriority,
        )
    }
    
    func determinant(item: Token) -> (Decimal, Decimal, Int) {
        let missingIconURL = "https://images.mixin.one/yH_I5b0GiV2zDmvrXRyr3bK5xusjfy5q7FX3lw3mM2Ryx4Dfuj6Xcw8SHNRnDKm7ZVE3_LvpKlLdcLrlFQUBhds=s128"
        let iconPriority = item.iconURL == missingIconURL ? 0 : 1
        return (
            item.decimalBalance * item.decimalUSDPrice,
            item.decimalBalance,
            iconPriority,
        )
    }
    
}
