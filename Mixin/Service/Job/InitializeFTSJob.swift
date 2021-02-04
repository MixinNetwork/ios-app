import Foundation
import MixinServices

class InitializeFTSJob: BaseJob {
    
    enum Error: Swift.Error {
        case mismatchedFTSTable
    }
    
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
            SELECT conversation_id, user_id, id, CASE WHEN category = 'SIGNAL_DATA' OR category = 'PLAIN_DATA' THEN name ELSE content END AS content, created_at
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
                    let lastInitializedRowID: Int?
                    let lastFTSMessageIDSQL = "SELECT ttou(id) FROM \(Message.ftsTableName) ORDER BY rowid DESC LIMIT 1"
                    if let lastFTSMessageID = try String.fetchOne(db, sql: lastFTSMessageIDSQL) {
                        lastInitializedRowID = try Int.fetchOne(db,
                                                                sql: "SELECT rowid FROM messages WHERE id=?",
                                                                arguments: [lastFTSMessageID])
                    } else {
                        lastInitializedRowID = -1
                    }
                    guard let rowID = lastInitializedRowID else {
                        throw Error.mismatchedFTSTable
                    }
                    try db.execute(sql: insertionSQL, arguments: [rowID])
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
