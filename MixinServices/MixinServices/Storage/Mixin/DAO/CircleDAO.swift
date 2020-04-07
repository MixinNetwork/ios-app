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
            ORDER BY c.created_at ASC
        """
        return MixinDatabase.shared.getCodables(sql: sql)
    }
    
    public func circleMembers(circleId: String) -> [CircleMember] {
        let sql = """
            SELECT
                conv.conversation_id, conv.owner_id, conv.category,
                CASE WHEN conv.category = 'CONTACT' THEN u.full_name ELSE conv.name END AS name,
                CASE WHEN conv.category = 'CONTACT' THEN u.avatar_url ELSE conv.icon_url END AS icon_url
            FROM circle_conversations cc
            LEFT JOIN conversations conv ON conv.conversation_id = cc.conversation_id
            LEFT JOIN users u ON u.user_id = conv.owner_id
            WHERE cc.circle_id = ?
        """
        return MixinDatabase.shared.getCodables(on: CircleMember.Properties.all,
                                                sql: sql,
                                                values: [circleId])
    }
    
    public func insertOrReplace(circles: [Circle]) {
        MixinDatabase.shared.insertOrReplace(objects: circles)
    }
    
    public func delete(circleId: String) {
        MixinDatabase.shared.delete(table: Circle.tableName, condition: Circle.Properties.circleId == circleId)
    }
    
    public func circles(of conversationId: String) -> [CircleItem] {
        let sql = """
            SELECT c.circle_id, c.name,
                (SELECT COUNT(*) FROM circle_conversations conv WHERE conv.circle_id = c.circle_id) as conversation_count
            FROM circles c
            INNER JOIN circle_conversations cc ON cc.circle_id = c.circle_id
            INNER JOIN conversations conv ON cc.conversation_id = conv.conversation_id
            WHERE conv.conversation_id = ?
            ORDER BY c.created_at ASC
        """
        return MixinDatabase.shared.getCodables(sql: sql, values: [conversationId])
    }
    
}
