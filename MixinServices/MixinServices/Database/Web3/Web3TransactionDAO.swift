import Foundation
import GRDB

public final class Web3TransactionDAO: Web3DAO {
    
    public static let shared = Web3TransactionDAO()
    
    public static let transactionDidSaveNotification = Notification.Name("one.mixin.services.Web3TransactionDAO.TransactionDidSave")
    public static let transactionsUserInfoKey = "s"
    
    public func transaction(id: String) -> Web3Transaction? {
        let sql = "SELECT * FROM transactions WHERE transaction_id = ?"
        return db.select(with: sql, arguments: [id])
    }
    
    public func transactions(assetID: String, limit: Int) -> [Web3Transaction] {
        let sql = """
        SELECT * from transactions txn
        WHERE txn.send_asset_id = ? OR txn.receive_asset_id = ?
        ORDER BY txn.transaction_at DESC
        LIMIT ?
        """
        return db.select(with: sql, arguments: [assetID, assetID, limit])
    }
    
    public func pendingTransactions() -> [Web3Transaction] {
        let sql = """
        SELECT * from transactions txn
        WHERE txn.status = '\(Web3RawTransaction.State.pending.rawValue)'
        ORDER BY txn.transaction_at DESC
        """
        return db.select(with: sql)
    }
    
    public func save(
        transactions: [Web3Transaction],
        alongsideTransaction change: ((GRDB.Database) throws -> Void)
    ) {
        guard !transactions.isEmpty else {
            return
        }
        db.write { db in
            try transactions.save(db)
            try change(db)
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
    
    public func updateExpiredTransaction(
        hash: String,
        chain: String,
        address: String,
        db: GRDB.Database
    ) throws {
        try db.execute(
            sql: "UPDATE transactions SET status = ? WHERE transaction_hash = ? AND chain_id = ? AND address = ?",
            arguments: [Web3RawTransaction.State.notFound.rawValue, hash, chain, address]
        )
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM transactions")
    }
    
}

extension Web3TransactionDAO {
    
    public enum Offset: CustomDebugStringConvertible {
        
        case before(offset: Web3Transaction, includesOffset: Bool)
        case after(offset: Web3Transaction, includesOffset: Bool)
        
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
        order: Web3Transaction.Order,
        limit: Int
    ) -> [Web3Transaction] {
        var query = GRDB.SQL(sql: "SELECT * from transactions txn\n")
        
        var conditions: [GRDB.SQL] = []
        
        switch filter.type {
        case .none:
            break
        case .receive:
            conditions.append("txn.transaction_type = 'transfer_in'")
        case .send:
            conditions.append("txn.transaction_type = 'transfer_out'")
        case .swap:
            conditions.append("txn.transaction_type = 'swap'")
        case .approval:
            conditions.append("txn.transaction_type = 'approval'")
        case .pending:
            conditions.append("txn.status = 'pending'")
        }
        
        if !filter.tokens.isEmpty {
            let assetIDs = filter.tokens.map(\.assetID)
            let assetConditions: [GRDB.SQL] = [
                "txn.send_asset_id IN \(assetIDs)",
                "txn.receive_asset_id IN \(assetIDs)",
            ]
            conditions.append("\(assetConditions.joined(operator: .or))")
        }
        
        var recipientConditions: [GRDB.SQL] = []
        for address in filter.addresses {
            let keyword = "%\(address.destination.sqlEscaped)%"
            recipientConditions.append(
                "txn.transaction_type = 'transfer_in' AND txn.senders LIKE \(keyword)"
            )
            recipientConditions.append(
                "txn.transaction_type = 'transfer_out' AND txn.receivers LIKE \(keyword)"
            )
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
        }
        
        query.append(literal: "\nLIMIT \(limit)")
        
        let results: [Web3Transaction] = db.select(with: query)
        if reverseResults {
            return results.reversed()
        } else {
            return results
        }
    }
    
}
