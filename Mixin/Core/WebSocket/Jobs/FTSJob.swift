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
        var rowid = MixinDatabase.shared.scalar(sql: "SELECT MIN(rowid) FROM messages WHERE category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA') AND status != 'FAILED' AND rowid not in (SELECT docid FROM fts_messages)").int64Value

        repeat {
            guard !isCancelled else {
                return
            }
            MixinDatabase.shared.transaction(callback: { (db) in
                let stmt = try db.prepareUpdateSQL(sql: "INSERT OR REPLACE INTO fts_messages(docid, message_id, conversation_id, content, name) SELECT rowid, id, conversation_id, content, name FROM messages WHERE rowid >= ? AND category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA') AND status != 'FAILED' ORDER BY rowid ASC LIMIT 1000")
                try stmt.execute(with: [rowid])
                if stmt.changes ?? 0 < 1000 {
                    isFinished = true
                } else {
                    rowid = rowid + 1000
                }
            })
            Thread.sleep(forTimeInterval: 0.1)
        } while !isFinished
        DatabaseUserDefault.shared.initiatedFTS = true
    }

}
