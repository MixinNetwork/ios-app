import Foundation
import GRDB

public final class Web3TransactionDAO: Web3DAO {
    
    public static let shared = Web3TransactionDAO()
    
    public static let transactionDidSaveNotification = Notification.Name("one.mixin.services.Web3TransactionDAO.TransactionDidSave")
    public static let transactionsUserInfoKey = "s"
    
    private static let selector = """
    SELECT txn.*,
        token.symbol AS \(Web3TransactionItem.JoinedQueryCodingKeys.tokenSymbol.rawValue),
        token.price_usd AS \(Web3TransactionItem.JoinedQueryCodingKeys.tokenUSDPrice.rawValue)
    FROM transactions txn
        LEFT JOIN tokens token ON txn.asset_id = token.asset_id
    
    """
    
    public func transaction(id: String) -> Web3Transaction? {
        let sql = "SELECT * FROM transactions WHERE transaction_id = ?"
        return db.select(with: sql, arguments: [id])
    }
    
    public func transactions(assetID: String, limit: Int) -> [Web3TransactionItem] {
        let sql = Self.selector + """
        WHERE txn.asset_id = ?
        ORDER BY txn.transaction_at DESC
        LIMIT ?
        """
        return db.select(with: sql, arguments: [assetID, limit])
    }
    
    public func save(
        transactions: [Web3Transaction],
        alongsideTransaction change: ((GRDB.Database) throws -> Void)
    ) {
        db.write { db in
            try transactions.save(db)
            try change(db)
            
            let hashes = transactions.map(\.transactionHash)
            let deletePendingTransactions: GRDB.SQL = """
            DELETE FROM transactions
            WHERE status = 'pending' AND transaction_hash IN \(hashes)
            """
            let (sql, arguments) = try deletePendingTransactions.build(db)
            try db.execute(sql: sql, arguments: arguments)
            
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Self.transactionDidSaveNotification,
                        object: self,
                        userInfo: [Self.transactionsUserInfoKey: transactions]
                    )
                }
            }
        }
    }
    
}

extension Web3TransactionDAO {
    
    public enum Offset: CustomDebugStringConvertible {
        
        case before(offset: Web3TransactionItem, includesOffset: Bool)
        case after(offset: Web3TransactionItem, includesOffset: Bool)
        
        public var debugDescription: String {
            switch self {
            case .before(let offset, let includesOffset):
                "<Offset before: \(offset), include: \(includesOffset)>"
            case .after(let offset, let includesOffset):
                "<Offset after: \(offset), include: \(includesOffset)>"
            }
        }
        
    }
    
    // The returned data will be ordered according to its display sequence.
    // For example, when requesting `newest`, the first item will be the most recent;
    // When requesting `biggestAmount`, the first item will have the largest amount.
    public func transactions(
        offset: Offset? = nil,
        filter: Web3Transaction.Filter,
        order: SafeSnapshot.Order,
        limit: Int
    ) -> [Web3TransactionItem] {
        var query = GRDB.SQL(sql: Self.selector)
        
        var conditions: [GRDB.SQL] = []
        
        if let type = filter.type {
            conditions.append("txn.transaction_type = \(type.rawValue)")
        }
        
        if !filter.tokens.isEmpty {
            conditions.append("txn.asset_id IN \(filter.tokens.map(\.assetID))")
        }
        
        var recipientConditions: [GRDB.SQL] = []
        for address in filter.addresses {
            let keyword = "%\(address.destination.sqlEscaped)%"
            let condition: GRDB.SQL = "txn.sender LIKE \(keyword) OR txn.receiver LIKE \(keyword)"
            recipientConditions.append(condition)
        }
        if !recipientConditions.isEmpty {
            conditions.append("\(recipientConditions.joined(operator: .or))")
        }
        
        if let startDate = filter.startDate?.toUTCString() {
            conditions.append("txn.transaction_at >= \(startDate)")
        }
        if let endDate = filter.endDate?.toUTCString() {
            conditions.append("txn.transaction_at <= \(endDate)")
        }
        
        if let offset {
            switch (order, offset) {
            case let (.oldest, .after(offset, includesOffset)), let (.newest, .before(offset, includesOffset)):
                if includesOffset {
                    conditions.append("txn.transaction_at >= \(offset.transactionAt)")
                } else {
                    conditions.append("txn.transaction_at > \(offset.transactionAt)")
                }
            case let (.oldest, .before(offset, includesOffset)), let (.newest, .after(offset, includesOffset)):
                if includesOffset {
                    conditions.append("txn.transaction_at <= \(offset.transactionAt)")
                } else {
                    conditions.append("txn.transaction_at < \(offset.transactionAt)")
                }
            case let (.mostValuable, .after(offset, includesOffset)):
                let candidate: GRDB.SQL = "(ABS(CAST(txn.amount AS REAL) * IFNULL(CAST(token.price_usd AS REAL), 0)), ABS(CAST(txn.amount AS REAL)), txn.transaction_at)"
                let offset: GRDB.SQL = "(ABS(CAST(\(offset.decimalAmount * (offset.decimalTokenUSDPrice ?? 0)) AS REAL)), ABS(CAST(\(offset.amount) AS REAL)), \(offset.transactionAt))"
                if includesOffset {
                    conditions.append("\(candidate) <= \(offset)")
                } else {
                    conditions.append("\(candidate) < \(offset)")
                }
            case let (.mostValuable, .before(offset, includesOffset)):
                let candidate: GRDB.SQL = "(ABS(CAST(txn.amount AS REAL) * IFNULL(CAST(token.price_usd AS REAL), 0)), ABS(CAST(txn.amount AS REAL)), txn.transaction_at)"
                let offset: GRDB.SQL = "(ABS(CAST(\(offset.decimalAmount * (offset.decimalTokenUSDPrice ?? 0)) AS REAL)), ABS(CAST(\(offset.amount) AS REAL)), \(offset.transactionAt))"
                if includesOffset {
                    conditions.append("\(candidate) >= \(offset)")
                } else {
                    conditions.append("\(candidate) > \(offset)")
                }
            case let (.biggestAmount, .after(offset, includesOffset)):
                let candidate: GRDB.SQL = "(ABS(CAST(txn.amount AS REAL)), txn.transaction_at)"
                let offset: GRDB.SQL = "(ABS(CAST(\(offset.amount) AS REAL)), \(offset.transactionAt))"
                if includesOffset {
                    conditions.append("\(candidate) <= \(offset)")
                } else {
                    conditions.append("\(candidate) < \(offset)")
                }
            case let (.biggestAmount, .before(offset, includesOffset)):
                let candidate: GRDB.SQL = "(ABS(CAST(txn.amount AS REAL)), txn.transaction_at)"
                let offset: GRDB.SQL = "(ABS(CAST(\(offset.amount) AS REAL)), \(offset.transactionAt))"
                if includesOffset {
                    conditions.append("\(candidate) >= \(offset)")
                } else {
                    conditions.append("\(candidate) > \(offset)")
                }
            }
        }
        if !conditions.isEmpty {
            query.append(literal: "WHERE \(conditions.joined(operator: .and))\n")
        }
        
        let reverseResults: Bool
        switch (order, offset) {
        case (.newest, .after), (.newest, .none):
            query.append(sql: "ORDER BY txn.transaction_at DESC")
            reverseResults = false
        case (.newest, .before):
            query.append(sql: "ORDER BY txn.transaction_at ASC")
            reverseResults = true
        case (.oldest, .after), (.oldest, .none):
            query.append(sql: "ORDER BY txn.transaction_at ASC")
            reverseResults = false
        case (.oldest, .before):
            query.append(sql: "ORDER BY txn.transaction_at DESC")
            reverseResults = true
        case (.mostValuable, .after), (.mostValuable, .none):
            query.append(sql: "ORDER BY ABS(txn.amount * token.price_usd) DESC, ABS(txn.amount) DESC, txn.transaction_at DESC")
            reverseResults = false
        case (.mostValuable, .before):
            query.append(sql: "ORDER BY ABS(txn.amount * token.price_usd) ASC, ABS(txn.amount) ASC, txn.transaction_at ASC")
            reverseResults = true
        case (.biggestAmount, .after), (.biggestAmount, .none):
            query.append(sql: "ORDER BY ABS(CAST(txn.amount AS REAL)) DESC, txn.transaction_at DESC")
            reverseResults = false
        case (.biggestAmount, .before):
            query.append(sql: "ORDER BY ABS(CAST(txn.amount AS REAL)) ASC, txn.transaction_at ASC")
            reverseResults = true
        }
        
        query.append(literal: "\nLIMIT \(limit)")
        
        let results: [Web3TransactionItem] = db.select(with: query)
        if reverseResults {
            return results.reversed()
        } else {
            return results
        }
    }
    
}
