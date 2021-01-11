import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    private static let insertionLimit: Int = 1000
    
    private let insertionSQL = """
        INSERT INTO \(Message.ftsTableName)(id, conversation_id, content, name)
        SELECT id, conversation_id, content, name
        FROM \(Message.databaseTableName)
        WHERE category in \(MessageCategory.ftsAvailableCategorySequence) AND status != 'FAILED' AND ROWID > ?
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
        
        var lastRowID: Int? = try lastInitializedRowID()
        var numberOfMessagesProcessed = 0
        let startDate = Date()
        
        while let rowID = lastRowID, !MixinService.isStopProcessMessages {
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
                    lastRowID = nil
                } else {
                    lastRowID = try lastInitializedRowID()
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
    
    private func lastInitializedRowID() throws -> Int? {
        let lastFTSMessageIDSQL = "SELECT id FROM \(Message.ftsTableName) ORDER BY rowid DESC LIMIT 1"
        return try UserDatabase.current.pool.read { (db) -> Int? in
            let lastFTSMessageID: String? = try String.fetchOne(db, sql: lastFTSMessageIDSQL)
            if let id = lastFTSMessageID {
                return try Int.fetchOne(db, sql: "SELECT rowid FROM messages WHERE id=?", arguments: [id])
            } else {
                return -1
            }
        }
    }
    
}
