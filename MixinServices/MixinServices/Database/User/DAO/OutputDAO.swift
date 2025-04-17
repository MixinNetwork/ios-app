import Foundation
import GRDB

public final class OutputDAO: UserDatabaseDAO {
    
    public enum ConflictResolution {
        case alwaysReplace
        case replaceIfNotSigned
    }
    
    public static let shared = OutputDAO()
    
    public static let didSignOutputNotification = Notification.Name("one.mixin.service.OutputDAO.DidSign")
    public static let didInsertInscriptionOutputsNotification = Notification.Name("one.mixin.service.OutputDAO.DidInsertInscriptions")
    public static let outputIDsUserInfoKey = "o"
    
    public func getOutput(inscriptionHash: String) -> Output? {
        db.select(with: "SELECT * FROM outputs WHERE inscription_hash = ? LIMIT 1", arguments: [inscriptionHash])
    }
    
    public func latestOutputSequence() -> Int? {
        db.select(with: "SELECT sequence FROM outputs ORDER BY sequence DESC LIMIT 1")
    }
    
    public func latestOutputSequence(asset: String) -> Int? {
        db.select(with: "SELECT sequence FROM outputs WHERE asset = ? ORDER BY sequence DESC LIMIT 1", arguments: [asset])
    }
    
    public func availableOutputs(asset: String, limit: Int) -> [Output] {
        let sql = """
        SELECT *
        FROM outputs
        WHERE state IN ('unspent','pending')
            AND asset = ?
            AND inscription_hash IS NULL
        ORDER BY created_at ASC
        LIMIT ?
        """
        return db.select(with: sql, arguments: [asset, limit])
    }
    
    public func availableOutputs(
        asset: String,
        createdAfter createdAt: String?,
        limit: Int,
        db: GRDB.Database
    ) throws -> [Output] {
        var query: GRDB.SQL = """
        SELECT *
        FROM outputs
        WHERE state IN ('unspent','pending')
            AND asset = \(asset)
            AND inscription_hash IS NULL
        
        """
        if let createdAt {
            query.append(literal: "AND created_at > \(createdAt)\n")
        }
        query.append(literal: "ORDER BY created_at ASC LIMIT \(limit)")
        
        let (sql, arguments) = try query.build(db)
        return try Output.fetchAll(db, sql: sql, arguments: arguments)
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
    
    public func insertOrReplace(
        outputs: [Output],
        onConflict resolution: ConflictResolution,
        alongsideTransaction work: ((GRDB.Database) throws -> Void)?
    ) {
        db.write { db in
            let outputsToSave: [Output]
            switch resolution {
            case .alwaysReplace:
                outputsToSave = outputs
            case .replaceIfNotSigned:
                let signedOutputIDs: Set<String> = try {
                    let query: GRDB.SQL = "SELECT output_id FROM outputs WHERE output_id IN \(outputs.map(\.id)) AND state = 'signed'"
                    let (sql, arguments) = try query.build(db)
                    let ids = try String.fetchAll(db, sql: sql, arguments: arguments)
                    return Set(ids)
                }()
                outputsToSave = outputs.filter { output in
                    !signedOutputIDs.contains(output.id)
                }
            }
            try outputsToSave.save(db)
            try work?(db)
            if outputsToSave.contains(where: { $0.inscriptionHash != nil }) {
                db.afterNextTransaction { _ in
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.didInsertInscriptionOutputsNotification, object: self)
                    }
                }
            }
        }
    }
    
    public func signOutputs(with ids: [String], alongsideTransaction change: ((GRDB.Database) throws -> Void)) {
        db.write { db in
            let ids = ids.joined(separator: "','")
            let sql = "UPDATE outputs SET state = 'signed' WHERE output_id IN ('\(ids)')"
            try db.execute(sql: sql)
            try change(db)
            // TODO: Too many notifications, just to update collectibles
            db.afterNextTransaction { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.didSignOutputNotification,
                                                    object: self,
                                                    userInfo: [Self.outputIDsUserInfoKey: ids])
                }
            }
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
