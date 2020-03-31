import WCDBSwift

public final class CircleDAO {
    
    public static let shared = CircleDAO()
    
    public func embeddedCircles() -> [EmbeddedCircle] {
        var circles = [EmbeddedCircle]()
        for category in EmbeddedCircle.Category.allCases {
            let circle: EmbeddedCircle
            switch category {
            case .all:
                let count = ConversationDAO.shared.getUnreadMessageCount()
                circle = EmbeddedCircle(conversationCount: -1, unreadCount: count)
            }
            circles.append(circle)
        }
        return circles
    }
    
    public func circles() -> [CircleItem] {
        let sql = """
            SELECT c.circle_id, c.name,
                (SELECT COUNT(*) FROM circle_conversations conv WHERE conv.circle_id = c.circle_id) as conversation_count,
                (SELECT SUM(unseen_message_count) FROM conversations conv INNER JOIN circle_conversations cc ON cc.circle_id = c.circle_id WHERE conv.conversation_id = cc.conversation_id) as unread_count
            FROM circles c
        """
        return MixinDatabase.shared.getCodables(sql: sql)
    }
    
}
