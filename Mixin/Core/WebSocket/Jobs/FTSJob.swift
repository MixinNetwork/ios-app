import Foundation

class FTSJob: BaseJob {

    override func getJobId() -> String {
        return "refresh-fts"
    }

    override func run() throws {
        guard !DatabaseUserDefault.shared.initiatedFTS else {
            return
        }

        var isFinished = false

        repeat {
            MixinDatabase.shared.transaction(callback: { (db) in
                let docid = MixinDatabase.shared.scalar(sql: "SELECT MAX(docid) FROM fts_messages").int64Value
                let stmt = try db.prepareUpdateSQL(sql: "INSERT OR REPLACE INTO fts_messages(docid, message_id, conversation_id, content, name) SELECT rowid, id, conversation_id, content, name FROM messages WHERE rowid > ? AND category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA') AND status != 'FAILED' LIMIT 2000")
                try stmt.execute(with: [docid])
                if stmt.changes ?? 0 < 2000 {
                    isFinished = true
                }
            })
            Thread.sleep(forTimeInterval: 0.1)
        } while !isFinished
        DatabaseUserDefault.shared.initiatedFTS = true
    }

}
