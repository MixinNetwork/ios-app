import Foundation
import GRDB

public final class OutputDAO: UserDatabaseDAO {
    
    public static let shared = OutputDAO()
    
    public func save(outputs: [Output], alongsideTransaction work: ((GRDB.Database) throws -> Void)?) {
        db.write { db in
            try outputs.save(db)
            try work?(db)
        }
    }
    
    public func latestOutputCreatedAt() -> Date? {
        if let string: String = db.select(with: "SELECT created_at FROM outputs ORDER BY created_at DESC LIMIT 1") {
            return ISO8601CompatibleDateFormatter.date(from: string)
        } else {
            return nil
        }
    }
    
    public func unspentUTXOs(asset: String) -> [Output] {
        db.select(with: "SELECT * FROM outputs WHERE state = 'unspent' AND asset = ? ORDER BY created_at ASC LIMIT 256", arguments: [asset])
    }
    
    public func signUTXOs(with hashs: [String], change: Output?, raw: RawTransaction) {
        db.write { db in
            let hashs = hashs.joined(separator: "','")
            let sql = "UPDATE outputs SET state = 'signed' WHERE transaction_hash IN ('\(hashs)')"
            try db.execute(sql: sql)
            try change?.save(db)
            try raw.save(db)
        }
    }
    
    public func spendUTXOs(with hashs: [String], changeOutputID: String?, raw: RawTransaction, snapshot: SafeSnapshot, message: Message) {
        db.write { db in
            let hashs = hashs.joined(separator: "','")
            try db.execute(sql: "UPDATE outputs SET state = 'spent' WHERE transaction_hash IN ('\(hashs)')")
            if let id = changeOutputID {
                try db.execute(sql: "UPDATE outputs SET state = 'unspent' WHERE output_id = ?", arguments: [id])
            }
            try db.execute(sql: "DELETE FROM raw_transactions WHERE request_id = ?", arguments: [raw.requestID])
            try snapshot.save(db)
            try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "OutputDAO", silentNotification: false)
        }
    }
    
}
