import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    private static let insertionLimit: Int = 1000
    
    private let firstUninitializedRowIDSQL = """
        SELECT MIN(ROWID) FROM messages
        WHERE category in \(MessageCategory.ftsAvailableCategorySequence)
            AND status != 'FAILED'
            AND ROWID > (SELECT IFNULL(MAX(ROWID), -1) FROM \(Message.ftsTableName))
    """
    
    private let insertionSQL = """
        INSERT INTO \(Message.ftsTableName)(id, conversation_id, content, name)
        SELECT id, conversation_id, content, name
        FROM \(Message.databaseTableName)
        WHERE category in \(MessageCategory.ftsAvailableCategorySequence) AND status != 'FAILED' AND ROWID >= ?
        ORDER BY created_at ASC
        LIMIT \(InitializeFTSJob.insertionLimit)
    """
    
    override func getJobId() -> String {
        return "initialize-fts"
    }
    
    override func run() throws {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        
        var nextRowID: Int? = UserDatabase.current.select(with: firstUninitializedRowIDSQL)
        var numberOfMessagesProcessed = 0
        let startDate = Date()
        
        while let rowID = nextRowID, !MixinService.isStopProcessMessages {
            guard !isCancelled else {
                return
            }
            do {
                var didInitializedAllMessages = false
                try UserDatabase.current.pool.barrierWriteWithoutTransaction { (db) -> Void in
                    try db.execute(sql: insertionSQL, arguments: [rowID])
                    let numberOfChanges = db.changesCount
                    numberOfMessagesProcessed += numberOfChanges
                    Logger.writeDatabase(log: "[FTS] \(numberOfChanges) messages are wrote into FTS table")
                    didInitializedAllMessages = numberOfChanges < Self.insertionLimit
                    if didInitializedAllMessages {
                        AppGroupUserDefaults.Database.isFTSInitialized = true
                    }
                }
                if didInitializedAllMessages {
                    nextRowID = nil
                } else {
                    nextRowID = UserDatabase.current.select(with: firstUninitializedRowIDSQL)
                }
            } catch {
                Logger.writeDatabase(error: error)
                reporter.report(error: error)
                return
            }
        }
        
        let interval = -startDate.timeIntervalSinceNow
        Logger.writeDatabase(log: "[FTS] Initialized \(numberOfMessagesProcessed) messages in \(interval)s")
    }
    
}
