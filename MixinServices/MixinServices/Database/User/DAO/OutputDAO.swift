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
    
    public func latestOutputSequence() -> Int? {
        db.select(with: "SELECT sequence FROM outputs ORDER BY sequence DESC LIMIT 1")
    }
    
    public func unspentOutputs(asset: String, limit: Int) -> [Output] {
        db.select(with: "SELECT * FROM outputs WHERE state = 'unspent' AND asset = ? ORDER BY sequence ASC LIMIT ?", arguments: [asset, limit])
    }
    
    public func unspentOutputs(asset: String, after sequence: Int?, limit: Int, db: GRDB.Database) throws -> [Output] {
        var sql = "SELECT * FROM outputs WHERE state = 'unspent' AND asset = :asset"
        var arguments: [String: DatabaseValueConvertible] = ["asset": asset]
        
        if let sequence {
            sql += " AND sequence > :sequence"
            arguments["sequence"] = sequence
        }
        
        sql += " ORDER BY sequence ASC LIMIT :limit"
        arguments["limit"] = limit
        
        return try Output.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
    }
    
    public func signOutputs(with ids: [String], alongsideTransaction change: ((GRDB.Database) throws -> Void)) {
        db.write { db in
            let ids = ids.joined(separator: "','")
            let sql = "UPDATE outputs SET state = 'signed' WHERE output_id IN ('\(ids)')"
            try db.execute(sql: sql)
            try change(db)
        }
    }
    
    public func spendOutputs(with ids: [String], raw: RawTransaction, snapshot: SafeSnapshot, message: Message) {
        db.write { db in
            let ids = ids.joined(separator: "','")
            try db.execute(sql: "UPDATE outputs SET state = 'spent' WHERE output_id IN ('\(ids)')")
            try db.execute(sql: "DELETE FROM raw_transactions WHERE request_id = ?", arguments: [raw.requestID])
            try snapshot.save(db)
            try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "OutputDAO", silentNotification: false)
        }
    }
    
    public func deleteAll() {
        db.execute(sql: "DELETE FROM outputs")
    }
    
}
