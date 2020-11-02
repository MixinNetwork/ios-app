import WCDBSwift

class FTSMessageDAO {
    
    static let shared = FTSMessageDAO()
    
    func insert(database: Database, messageId: String, category: String) throws {
        guard let category = MessageCategory(rawValue: category), MessageCategory.ftsAvailable.contains(category) else {
            return
        }
        let sql = """
        INSERT OR REPLACE INTO \(FTSMessage.tableName)(docid, message_id, conversation_id, content, name)
        SELECT rowid, id, conversation_id, content, name
        FROM messages
        WHERE id = ?
        """
        try database.prepareUpdateSQL(sql: sql).execute(with: [messageId])
    }
    
    func remove(database: Database, messageId: String) throws {
        try database
            .prepareUpdateSQL(sql: "DELETE FROM \(FTSMessage.tableName) WHERE docid = (SELECT ROWID FROM messages WHERE id = ?)")
            .execute(with: [messageId])
    }
    
}
