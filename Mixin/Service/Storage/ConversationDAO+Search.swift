import Foundation
import GRDB
import MixinServices

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
    WHERE m.category in ('SIGNAL_TEXT','SIGNAL_DATA','SIGNAL_POST','PLAIN_TEXT','PLAIN_DATA','PLAIN_POST') AND m.status != 'FAILED'
    AND (m.content LIKE ? ESCAPE '/' OR m.name LIKE ? ESCAPE '/')
    GROUP BY m.conversation_id
    ORDER BY c.pin_time DESC, c.last_message_created_at DESC
    """
    
    func getConversation(withMessageLike keyword: String, limit: Int?, completion: ([MessagesWithinConversationSearchResult]) -> Void) -> DatabaseSnapshot {
        var sql = ConversationDAO.sqlSearchMessages
        if let limit = limit {
            sql += " LIMIT \(limit)"
        }
        let keyword = "%\(keyword.sqlEscaped)%"
        let snapshot = try! UserDatabase.current.pool.makeSnapshot()
        defer {
            try! snapshot.read { (db) -> Void in
                var items = [MessagesWithinConversationSearchResult]()
                let rows = try Row.fetchCursor(db, sql: sql, arguments: [keyword, keyword], adapter: nil)
                while let row = try rows.next() {
                    let counter = Counter(value: -1)
                    let conversationId: String = row[counter.advancedValue] ?? ""
                    let categoryString: String = row[counter.advancedValue] ?? ""
                    guard let category = ConversationCategory(rawValue: categoryString) else {
                        continue
                    }
                    let name: String = row[counter.advancedValue] ?? ""
                    let iconUrl: String = row[counter.advancedValue] ?? ""
                    let userId: String = row[counter.advancedValue] ?? ""
                    let userIsVerified: Bool = row[counter.advancedValue] ?? false
                    let userAppId: String? = row[counter.advancedValue]
                    let relatedMessageCount: Int = row[counter.advancedValue] ?? 0
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
            }
        }
        return snapshot
    }
    
}
