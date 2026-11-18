import Foundation

public protocol ComparableToken: ValuableToken {
    var chainName: String? { get }
    var level: Int { get }
}

extension MixinTokenItem: ComparableToken {
    
    public var chainName: String? {
        chain?.name
    }
    
}

extension Web3TokenItem: ComparableToken {
    
    public var chainName: String? {
        chain?.name
    }
    
}

public struct TokenOrdering: Hashable, Sendable {
    
    private enum Key: Hashable, Sendable {
        case symbolMatch
        case usdBalance
        case level
        case balance
        case usdPrice
        case name
        case chainName
    }
    
    private enum Direction: String, Hashable, Sendable {
        case ascending = "ASC"
        case descending = "DESC"
    }
    
    private struct Rule: Hashable, Sendable {
        let key: Key
        let direction: Direction
    }
    
    private static let listRules: [Rule] = [
        Rule(key: .usdBalance,  direction: .descending),
        Rule(key: .level,       direction: .descending),
        Rule(key: .balance,     direction: .descending),
        Rule(key: .usdPrice,    direction: .descending),
        Rule(key: .name,        direction: .ascending),
        Rule(key: .chainName,   direction: .ascending),
    ]
    
    private let rules: [Rule]
    private let keyword: String?
    
    public init(keyword: String?) {
        self.keyword = keyword
        self.rules = if keyword == nil {
            Self.listRules
        } else {
            [Rule(key: .symbolMatch, direction: .descending)] + Self.listRules
        }
    }
    
    public func compare<Token: ComparableToken>(_ lhs: Token, _ rhs: Token) -> ComparisonResult {
        for rule in rules {
            let result: ComparisonResult
            switch rule.key {
            case .symbolMatch:
                guard let keyword else {
                    continue
                }
                let left = KeywordMatchingRank.evaluate(text: lhs.symbol, keyword: keyword)
                let right = KeywordMatchingRank.evaluate(text: rhs.symbol, keyword: keyword)
                result = compareValues(left, right)
            case .usdBalance:
                result = compareValues(
                    lhs.decimalBalance * lhs.decimalUSDPrice,
                    rhs.decimalBalance * rhs.decimalUSDPrice,
                )
            case .level:
                result = compareValues(lhs.level, rhs.level)
            case .balance:
                result = compareValues(lhs.decimalBalance, rhs.decimalBalance)
            case .usdPrice:
                result = compareValues(lhs.decimalUSDPrice, rhs.decimalUSDPrice)
            case .name:
                result = compareNames(lhs.name, rhs.name)
            case .chainName:
                result = compareNames(lhs.chainName, rhs.chainName)
            }
            guard result != .orderedSame else {
                continue
            }
            switch rule.direction {
            case .ascending:
                return result
            case .descending:
                return result == .orderedAscending ? .orderedDescending : .orderedAscending
            }
        }
        return .orderedSame
    }
    
    // Both DAO selectors use t for tokens and c for chains. Only the balance column differs.
    // Search callers bind :keyword to the unwrapped keyword used by the comparator.
    func sqlOrder(balance: String) -> String {
        rules.map { rule in
            let expression: String
            switch rule.key {
            case .symbolMatch:
                expression = "keyword_match(t.symbol, :keyword)"
            case .usdBalance:
                expression = "ifnull(\(balance),0) * t.price_usd"
            case .level:
                expression = "t.level"
            case .balance:
                expression = "CAST(ifnull(\(balance),0) AS REAL)"
            case .usdPrice:
                expression = "CAST(t.price_usd AS REAL)"
            case .name:
                expression = "t.name"
            case .chainName:
                expression = "c.name"
            }
            return "\(expression) \(rule.direction.rawValue)"
        }.joined(separator: ", ")
    }
    
    private func compareValues<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }
    
    private func compareNames(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil):
            return .orderedSame
        case (nil, .some):
            return .orderedAscending
        case (.some, nil):
            return .orderedDescending
        case let (left?, right?):
            // SQLite BINARY compares UTF-8 bytes, without Unicode normalization.
            if left.utf8.elementsEqual(right.utf8) {
                return .orderedSame
            }
            return left.utf8.lexicographicallyPrecedes(right.utf8) ? .orderedAscending : .orderedDescending
        }
    }
    
}
