import Foundation
import GRDB

public final class OutputDAO: UserDatabaseDAO {
    
    public static let shared = OutputDAO()
    
    public func getOutput(inscriptionHash: String) -> Output? {
        db.select(with: "SELECT * FROM outputs WHERE inscription_hash = ? LIMIT 1", arguments: [inscriptionHash])
    }
    
    public func latestOutputSequence() -> Int? {
        db.select(with: "SELECT sequence FROM outputs ORDER BY sequence DESC LIMIT 1")
    }
    
    public func latestOutputSequence(asset: String) -> Int? {
        db.select(with: "SELECT sequence FROM outputs WHERE asset = ? ORDER BY sequence DESC LIMIT 1", arguments: [asset])
    }
    
    public func unspentOutputs(asset: String, limit: Int) -> [Output] {
        db.select(with: "SELECT * FROM outputs WHERE state = 'unspent' AND asset = ? AND inscription_hash IS NULL ORDER BY sequence ASC LIMIT ?", arguments: [asset, limit])
    }
    
    public func unspentOutputs(asset: String, after sequence: Int?, limit: Int, db: GRDB.Database) throws -> [Output] {
        var sql = "SELECT * FROM outputs WHERE state = 'unspent' AND asset = :asset AND inscription_hash IS NULL"
        var arguments: [String: DatabaseValueConvertible] = ["asset": asset]
        
        if let sequence {
            sql += " AND sequence > :sequence"
            arguments["sequence"] = sequence
        }
        
        sql += " ORDER BY sequence ASC LIMIT :limit"
        arguments["limit"] = limit
        
        return try Output.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
    }
    
    public func outputs(asset: String?, before outputID: String?, limit: Int) -> [Output] {
        var sql = "SELECT * FROM outputs WHERE inscription_hash IS NULL"
        
        var conditions: [String] = []
        var arguments: [String: any DatabaseValueConvertible] = ["limit": limit]
        if let asset {
            conditions.append("asset = :asset")
            arguments["asset"] = asset
        }
        if let outputID {
            conditions.append("rowid < (SELECT rowid FROM outputs WHERE output_id = :id LIMIT 1)")
            arguments["id"] = outputID
        }
        if !conditions.isEmpty {
            sql += " AND \(conditions.joined(separator: " AND "))"
        }
        
        sql += " ORDER BY rowid DESC LIMIT :limit"
        return db.select(with: sql, arguments: StatementArguments(arguments))
    }
    
    public func insertOrIgnore(outputs: [Output], alongsideTransaction work: ((GRDB.Database) throws -> Void)?) {
        db.write { db in
            try outputs.insert(db, onConflict: .ignore)
            try work?(db)
        }
    }
    
    public func signOutputs(with ids: [String], alongsideTransaction change: ((GRDB.Database) throws -> Void)) {
        db.write { db in
            let ids = ids.joined(separator: "','")
            let sql = "UPDATE outputs SET state = 'signed' WHERE output_id IN ('\(ids)')"
            try db.execute(sql: sql)
            try change(db)
        }
    }
    
    public func deleteAll(kernelAssetID: String, completion: (() -> Void)? = nil) {
        db.write { db in
            try db.execute(sql: "DELETE FROM outputs WHERE asset = ?", arguments: [kernelAssetID])
            try db.afterNextTransaction(onCommit: { _ in
                completion?()
            })
        }
    }
    
    public func deleteAll(completion: (() -> Void)? = nil) {
        db.write { db in
            try db.execute(sql: "DELETE FROM outputs")
            try db.afterNextTransaction(onCommit: { _ in
                completion?()
            })
        }
    }
    
}
