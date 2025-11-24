import Foundation
import GRDB
import MixinServices

extension Web3OrderDAO {
    
    enum Offset: CustomDebugStringConvertible {
        
        case before(offset: SwapOrderViewModel, includesOffset: Bool)
        case after(offset: SwapOrderViewModel, includesOffset: Bool)
        
        var debugDescription: String {
            switch self {
            case .before(let offset, let includesOffset):
                "<Offset before: \(offset.createdAt), include: \(includesOffset)>"
            case .after(let offset, let includesOffset):
                "<Offset after: \(offset.createdAt), include: \(includesOffset)>"
            }
        }
        
    }
    
    // The returned data will be ordered according to its display sequence.
    // For example, when requesting `newest`, the first item will be the most recent;
    // When requesting `biggestAmount`, the first item will have the largest amount.
    func orders(
        offset: Offset? = nil,
        filter: SwapOrder.Filter,
        sorting: SwapOrder.Sorting,
        limit: Int
    ) -> [SwapOrder] {
        var query = GRDB.SQL(sql: "SELECT * FROM orders\n")
        
        var conditions: [GRDB.SQL] = []
        
        if !filter.wallets.isEmpty {
            let walletIDs = filter.wallets.map { wallet in
                switch wallet {
                case .privacy:
                    myUserId
                case .common(let wallet):
                    wallet.walletID
                }
            }
            conditions.append("wallet_id IN \(walletIDs)")
        }
        
        if let type = filter.type {
            switch type {
            case .swap:
                conditions.append("order_type = \(SwapOrder.OrderType.swap.rawValue)")
            case .limit:
                conditions.append("order_type = \(SwapOrder.OrderType.limit.rawValue)")
            }
        }
        
        if let states = filter.status?.states {
            conditions.append("state IN \(states.map(\.rawValue))")
        }
        
        if let startDate = filter.startDate?.toUTCString() {
            conditions.append("created_at >= \(startDate)")
        }
        if let endDate = filter.endDate?.toUTCString() {
            conditions.append("created_at <= \(endDate)")
        }
        
        if let offset {
            switch (sorting, offset) {
            case let (.oldest, .after(offset, includesOffset)), let (.newest, .before(offset, includesOffset)):
                if includesOffset {
                    conditions.append("created_at >= \(offset.createdAt)")
                } else {
                    conditions.append("created_at > \(offset.createdAt)")
                }
            case let (.oldest, .before(offset, includesOffset)), let (.newest, .after(offset, includesOffset)):
                if includesOffset {
                    conditions.append("created_at <= \(offset.createdAt)")
                } else {
                    conditions.append("created_at < \(offset.createdAt)")
                }
            }
        }
        if !conditions.isEmpty {
            query.append(literal: "WHERE \(conditions.joined(operator: .and))\n")
        }
        
        let reverseResults: Bool
        switch (sorting, offset) {
        case (.newest, .after), (.newest, .none):
            query.append(sql: "ORDER BY created_at DESC")
            reverseResults = false
        case (.newest, .before):
            query.append(sql: "ORDER BY created_at ASC")
            reverseResults = true
        case (.oldest, .after), (.oldest, .none):
            query.append(sql: "ORDER BY created_at ASC")
            reverseResults = false
        case (.oldest, .before):
            query.append(sql: "ORDER BY created_at DESC")
            reverseResults = true
        }
        
        query.append(literal: "\nLIMIT \(limit)")
        
        let results: [SwapOrder] = db.select(with: query)
        if reverseResults {
            return results.reversed()
        } else {
            return results
        }
    }
    
}

extension Web3OrderDAO {
    
    func swapOrderTokens(orders: [SwapOrder]) -> [String: SwapOrder.Token] {
        var assetIDs: Set<String> = []
        for order in orders {
            assetIDs.insert(order.payAssetID)
            assetIDs.insert(order.receiveAssetID)
        }
        var tokens: [String: SwapOrder.Token] = [:]
        for assetID in assetIDs {
            if let token = TokenDAO.shared.swapOrderToken(id: assetID) {
                tokens[assetID] = token
            } else if let token = Web3TokenDAO.shared.swapOrderToken(id: assetID) {
                tokens[assetID] = token
            }
        }
        return tokens
    }
    
}
