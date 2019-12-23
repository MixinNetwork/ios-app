import Foundation
import WCDBSwift

extension ConversationDAO {
    
    private static let sqlSearchMessages = """
    SELECT m.conversation_id, c.category,
    CASE c.category WHEN 'CONTACT' THEN u.full_name ELSE c.name END,
    CASE c.category WHEN 'CONTACT' THEN u.avatar_url ELSE c.icon_url END,
    CASE c.category WHEN 'CONTACT' THEN u.user_id ELSE NULL END,
    u.is_verified, u.app_id, COUNT(m.conversation_id)
    FROM messages m
    LEFT JOIN conversations c ON m.conversation_id = c.conversation_id
    LEFT JOIN users u ON c.owner_id = u.user_id
    WHERE m.category in ('SIGNAL_TEXT', 'SIGNAL_DATA','PLAIN_TEXT','PLAIN_DATA') AND m.status != 'FAILED'
    AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    GROUP BY m.conversation_id
    ORDER BY c.pin_time DESC, c.last_message_created_at DESC
    """
    
    func getConversation(withMessageLike keyword: String, limit: Int?, callback: (CoreStatement) -> Void) -> [MessagesWithinConversationSearchResult] {
        var sql = ConversationDAO.sqlSearchMessages
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        let keyword = "%\(keyword.sqlEscaped)%"
        let stmt = StatementSelectSQL(sql: sql)
        var items = [MessagesWithinConversationSearchResult]()
        let cs = try! MixinDatabase.shared.database.prepare(stmt)
        callback(cs)
        cs.bind(keyword, toIndex: 0)
        cs.bind(keyword, toIndex: 1)
        while (try? cs.step()) ?? false {
            var i = -1
            var autoIncrement: Int {
                i += 1
                return i
            }
            let conversationId: String = cs.value(atIndex: autoIncrement) ?? ""
            let categoryString: String = cs.value(atIndex: autoIncrement) ?? ""
            guard let category = ConversationCategory(rawValue: categoryString) else {
                continue
            }
            let name = cs.value(atIndex: autoIncrement) ?? ""
            let iconUrl = cs.value(atIndex: autoIncrement) ?? ""
            let userId = cs.value(atIndex: autoIncrement) ?? ""
            let userIsVerified = cs.value(atIndex: autoIncrement) ?? false
            let userAppId: String? = cs.value(atIndex: autoIncrement)
            let relatedMessageCount = cs.value(atIndex: autoIncrement) ?? 0
            let item: MessagesWithinConversationSearchResult
            switch category {
            case .CONTACT:
                item = MessagesWithUserSearchResult(conversationId: conversationId,
                                                    name: name,
                                                    iconUrl: iconUrl,
                                                    userId: userId,
                                                    userIsVerified: userIsVerified,
                                                    userAppId: userAppId,
                                                    relatedMessageCount: relatedMessageCount,
                                                    keyword: keyword)
            case .GROUP:
                item = MessagesWithGroupSearchResult(conversationId: conversationId,
                                                     name: name,
                                                     iconUrl: iconUrl,
                                                     relatedMessageCount: relatedMessageCount,
                                                     keyword: keyword)
            }
            items.append(item)
        }
        return items
    }
    
}
