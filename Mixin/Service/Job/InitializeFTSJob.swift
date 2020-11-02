import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    private let insertionLimit: Int64 = 1000
    
    override func getJobId() -> String {
        return "initialize-fts"
    }
    
    override func run() throws {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        
        let categories = "('" + MessageCategory.ftsAvailable.map(\.rawValue).joined(separator: "','") + "')"
        let rowIdSql = """
        SELECT MIN(rowid) FROM messages
        WHERE category in \(categories)
        AND status != 'FAILED'
        AND rowid NOT IN (SELECT docid FROM \(FTSMessage.tableName))
        """
        let insertionSql = """
        INSERT INTO \(FTSMessage.tableName)(docid, message_id, conversation_id, content, name)
        SELECT rowid, id, conversation_id, content, name
        FROM \(Message.tableName)
        WHERE rowid >= ?
        AND category in \(categories)
        AND status != 'FAILED'
        ORDER BY rowid
        ASC LIMIT \(insertionLimit)
        """
        
        var isFinished = false
        var rowid = MixinDatabase.shared.scalar(sql: rowIdSql).int64Value
        
        repeat {
            guard !isCancelled else {
                return
            }
            
            let stmt = try MixinDatabase.shared.database.prepareUpdateSQL(sql: insertionSql)
            try stmt.execute(with: [rowid])
            if (stmt.changes ?? 0) < insertionLimit {
                isFinished = true
            } else {
                rowid += insertionLimit
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while !isFinished
        
        AppGroupUserDefaults.Database.isFTSInitialized = true
    }
    
}
