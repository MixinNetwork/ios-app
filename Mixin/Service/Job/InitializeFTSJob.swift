import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    private static let insertionLimit: Int = {
        switch DevicePerformance.current {
        case .low:
            return 100
        case .medium:
            return 500
        case .high:
            return 1000
        }
    }()
    
    private let insertionSQL = """
        INSERT INTO \(Message.ftsTableName)
        SELECT utot(conversation_id), utot(user_id), utot(id), content, i8tout(created_at), NULL, NULL FROM (
            SELECT conversation_id, user_id, id, fts_content(id, category, content, name) AS content, created_at
            FROM \(Message.databaseTableName)
            WHERE category in \(MessageCategory.ftsAvailableCategorySequence) AND status != 'FAILED' AND rowid > ?
            ORDER BY rowid ASC
            LIMIT \(InitializeFTSJob.insertionLimit)
        )
    """
    
    override func getJobId() -> String {
        return "initialize-fts"
    }
    
    override func run() throws {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        let messageCount = UserDatabase.current.count(in: Message.self)
        Logger.writeDatabase(log: "[FTS] Database file size \(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
        Logger.writeDatabase(log: "[FTS] Make fts content with \(messageCount) messages")
        
        var didInitializedAllMessages = false
        var numberOfMessagesProcessed = 0
        let startDate = Date()
        
        while !didInitializedAllMessages && !MixinService.isStopProcessMessages {
            guard !isCancelled else {
                return
            }
            do {
                try UserDatabase.current.pool.write { (db) -> Void in
                    let lastInitializedRowID: Int
                    let lastFTSMessageIDSQL = "SELECT id FROM \(Message.ftsTableName) ORDER BY rowid DESC LIMIT 1"
                    let lastFTSMessageIDToken: String? = try String.fetchOne(db, sql: lastFTSMessageIDSQL)
                    if let token = lastFTSMessageIDToken {
                        let messageId = uuidString(uuidTokenString: token)
                        let rowID: Int? = try Int.fetchOne(db,
                                                           sql: "SELECT rowid FROM messages WHERE id=?",
                                                           arguments: [messageId])
                        if let rowID = rowID {
                            lastInitializedRowID = rowID
                        } else {
                            try db.execute(sql: "DELETE FROM \(Message.ftsTableName) WHERE id MATCH ?", arguments: ["\"\(token)\""])
                            Logger.writeDatabase(log: "[FTS] A mismatched record is detected and removed")
                            return
                        }
                    } else {
                        lastInitializedRowID = -1
                    }
                    try db.execute(sql: insertionSQL, arguments: [lastInitializedRowID])
                    let numberOfChanges = db.changesCount
                    numberOfMessagesProcessed += numberOfChanges
                    Logger.writeDatabase(log: "[FTS] \(numberOfChanges) messages are wrote into FTS table")
                    didInitializedAllMessages = numberOfChanges < Self.insertionLimit
                    if didInitializedAllMessages {
                        AppGroupUserDefaults.Database.isFTSInitialized = true
                    }
                }
            } catch {
                Logger.writeDatabase(error: error)
                reporter.report(error: error)
                return
            }
            usleep(100 * 1000)
        }
        
        let interval = -startDate.timeIntervalSinceNow
        Logger.writeDatabase(log: "[FTS] Initialized \(numberOfMessagesProcessed) messages in \(interval)s")
    }
    
}
