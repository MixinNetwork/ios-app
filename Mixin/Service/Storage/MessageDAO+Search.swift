import Foundation
import WCDBSwift
import MixinServices

extension MessageDAO {
    
    static let sqlSearchMessageContent = """
    SELECT m.id, m.category, m.content, m.created_at, u.user_id, u.full_name, u.avatar_url, u.is_verified, u.app_id
        FROM messages m
        LEFT JOIN users u ON m.user_id = u.user_id
        WHERE conversation_id = ? AND m.category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA')
        AND m.status != 'FAILED' AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    """
    
    func getMessages(conversationId: String, contentLike keyword: String, belowMessageId location: String?, limit: Int?) -> [MessageSearchResult] {
        var results = [MessageSearchResult]()
        
        var sql: String!
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location)
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
            let stmt = StatementSelectSQL(sql: sql)
            let cs = try MixinDatabase.shared.database.prepare(stmt)
            
            let bindingCounter = Counter(value: 0)
            let wildcardedKeyword = "%\(keyword.sqlEscaped)%"
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
            Reporter.report(error: error)
        }
        
        return results
    }
    
}
