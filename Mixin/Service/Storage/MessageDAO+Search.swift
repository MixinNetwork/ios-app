import Foundation
import WCDBSwift
import MixinServices

extension MessageDAO {
    
    static let sqlSearchMessageContent = """
    SELECT m.id, m.category, m.content, m.created_at, u.user_id, u.full_name, u.avatar_url, u.is_verified, u.app_id
        FROM messages m
        LEFT JOIN users u ON m.user_id = u.user_id
    """
    
    func getMessages(conversationId: String, contentLike keyword: String, belowMessageId location: String?, limit: Int?) -> [MessageSearchResult] {
        var results = [MessageSearchResult]()
        
        var sql = MessageDAO.sqlSearchMessageContent
        if AppGroupUserDefaults.Database.isFTSInitialized {
            sql += "WHERE m.id in (SELECT message_id FROM fts_messages WHERE conversation_id = ? AND (content MATCH ? OR name MATCH ?))"
        } else {
            sql += "WHERE conversation_id = ? AND m.category in ('SIGNAL_TEXT','SIGNAL_DATA','SIGNAL_POST','PLAIN_TEXT','PLAIN_DATA','PLAIN_POST') AND m.status != 'FAILED' AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')"
        }
        
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location)
            sql += " AND m.ROWID < \(rowId)"
        }
        
        if let limit = limit {
            sql += " ORDER BY m.created_at DESC LIMIT \(limit)"
        } else {
            sql += " ORDER BY m.created_at DESC"
        }
        
        do {
            let wildcardedKeyword = AppGroupUserDefaults.Database.isFTSInitialized ? keyword + "*" : "%\(keyword.sqlEscaped)%"
            let stmt = StatementSelectSQL(sql: sql)
            let cs = try MixinDatabase.shared.database.prepare(stmt)
            
            let bindingCounter = Counter(value: 0)
            cs.bind(conversationId, toIndex: bindingCounter.advancedValue)
            cs.bind(wildcardedKeyword, toIndex: bindingCounter.advancedValue)
            cs.bind(wildcardedKeyword, toIndex: bindingCounter.advancedValue)
            
            while try cs.step() {
                let counter = Counter(value: -1)
                let result = MessageSearchResult(conversationId: conversationId,
                                                 messageId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 category: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 content: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 createdAt: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 userId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 fullname: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 avatarUrl: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 isVerified: cs.value(atIndex: counter.advancedValue) ?? false,
                                                 appId: cs.value(atIndex: counter.advancedValue) ?? "",
                                                 keyword: keyword)
                results.append(result)
            }
        } catch {
            reporter.report(error: error)
        }
        
        return results
    }
    
}
