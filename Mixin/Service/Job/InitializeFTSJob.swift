import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    private let insertionLimit: Int = 1000
    
    override func getJobId() -> String {
        return "initialize-fts"
    }
    
    override func run() throws {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        
        let categories = "('" + MessageCategory.ftsAvailable.map(\.rawValue).joined(separator: "','") + "')"
        let insertionSql = """
        INSERT OR REPLACE INTO \(FTSMessage.tableName)(docid, message_id, conversation_id, content, name)
        SELECT rowid, id, conversation_id, content, name
        FROM \(Message.tableName)
        WHERE category in \(categories) AND status != 'FAILED'
        LIMIT \(insertionLimit) OFFSET ?
        """

        var offset = AppGroupUserDefaults.Database.ftsOffset
        Logger.writeDatabase(log: "[FTS]...init...offset:\(offset)", newSection: true)
        
        var isFinished = false
        var numberOfMessagesProcessed = 0
        let startDate = Date()
        
        repeat {
            guard !isCancelled else {
                return
            }
            
            do {
                let stmt = try MixinDatabase.shared.database.prepareUpdateSQL(sql: insertionSql)
                try stmt.execute(with: [offset])
                let numberOfChanges = stmt.changes ?? 0
                numberOfMessagesProcessed += numberOfChanges
                if numberOfChanges < insertionLimit {
                    isFinished = true
                } else {
                    offset += insertionLimit
                }
                
                Logger.writeDatabase(log: "[FTS]...processing...offset:\(offset)...numberOfChanges:\(numberOfChanges)")
                AppGroupUserDefaults.Database.ftsOffset = offset
                
                Thread.sleep(forTimeInterval: 0.1)
            } catch {
                Logger.writeDatabase(error: error)
                reporter.report(error: error)
                return
            }
        } while !isFinished && !MixinService.isStopProcessMessages
        
        let interval = -startDate.timeIntervalSinceNow
        Logger.writeDatabase(log: "[FTS]...Initialized \(numberOfMessagesProcessed) messages in \(interval)s...offset:\(offset)")
        
        AppGroupUserDefaults.Database.ftsOffset = 0
        AppGroupUserDefaults.Database.isFTSInitialized = true
    }
    
}
