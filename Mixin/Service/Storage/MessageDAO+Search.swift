import Foundation
import GRDB
import MixinServices

extension MessageDAO {
    
    static let sqlSearchMessageContent = """
    SELECT m.id, m.category, m.content, m.created_at, u.user_id, u.full_name, u.avatar_url, u.is_verified, u.app_id
        FROM messages m
        LEFT JOIN users u ON m.user_id = u.user_id
        WHERE conversation_id = ? AND m.category in ('SIGNAL_TEXT','SIGNAL_DATA','SIGNAL_POST','PLAIN_TEXT','PLAIN_DATA','PLAIN_POST')
        AND m.status != 'FAILED' AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    """
    
    func getMessages(conversationId: String, contentLike keyword: String, belowMessageId location: String?, limit: Int?) -> [MessageSearchResult] {
        var results = [MessageSearchResult]()
        
        var sql: String
        if let location = location, let rowId: Int = UserDatabase.current.select(column: .rowID, from: Message.self, where: Message.column(of: .messageId) == location) {
            sql = MessageDAO.sqlSearchMessageContent + " AND m.ROWID < \(rowId)"
        } else {
            sql = MessageDAO.sqlSearchMessageContent
        }
        if let limit = limit {
            sql += " ORDER BY m.created_at DESC LIMIT \(limit)"
        } else {
            sql += " ORDER BY m.created_at DESC"
        }
        
        do {
            try UserDatabase.current.pool.read { (db) -> Void in
                let wildcardedKeyword = "%\(keyword.sqlEscaped)%"
                let arguments = StatementArguments([conversationId, wildcardedKeyword, wildcardedKeyword])
                let rows = try Row.fetchCursor(db, sql: sql, arguments: arguments, adapter: nil)
                while let row = try rows.next() {
                    let counter = Counter(value: -1)
                    let result = MessageSearchResult(conversationId: conversationId,
                                                     messageId: row[counter.advancedValue] ?? "",
                                                     category: row[counter.advancedValue] ?? "",
                                                     content: row[counter.advancedValue] ?? "",
                                                     createdAt: row[counter.advancedValue] ?? "",
                                                     userId: row[counter.advancedValue] ?? "",
                                                     fullname: row[counter.advancedValue] ?? "",
                                                     avatarUrl: row[counter.advancedValue] ?? "",
                                                     isVerified: row[counter.advancedValue] ?? false,
                                                     appId: row[counter.advancedValue] ?? "",
                                                     keyword: keyword)
                    results.append(result)
                }
            }
        } catch {
            Logger.writeDatabase(error: error)
            reporter.report(error: error)
        }
        
        return results
    }
    
}
