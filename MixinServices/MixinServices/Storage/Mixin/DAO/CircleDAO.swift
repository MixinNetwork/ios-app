import GRDB

public final class CircleDAO: UserDatabaseDAO {
    
    public static let shared = CircleDAO()
    
    public static let circleDidChangeNotification = Notification.Name("one.mixin.messenger.circle.did_change")
    
    public func save(circle: CircleResponse) {
        let circle = Circle(circleId: circle.circleId, name: circle.name, createdAt: circle.createdAt)
        db.save(circle) { _ in
            NotificationCenter.default.post(onMainThread: Self.circleDidChangeNotification, object: nil)
        }
    }
    
    public func isExist(circleId: String) -> Bool {
        db.recordExists(in: Circle.self,
                        where: Circle.column(of: .circleId) == circleId)
    }
    
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
        return db.select(with: sql)
    }
    
    public func circleMembers(circleId: String) -> [CircleMember] {
        let sql = """
            SELECT
                cc.conversation_id, cc.user_id as owner_id,
                CASE WHEN conv.category IS NULL THEN 'CONTACT' ELSE conv.category END AS category,
                CASE WHEN conv.category = 'GROUP' THEN conv.name ELSE u.full_name END AS name,
                CASE WHEN conv.category = 'GROUP' THEN conv.icon_url ELSE u.avatar_url END AS icon_url,
                u.identity_number, u.phone
            FROM circle_conversations cc
            LEFT JOIN conversations conv ON conv.conversation_id = cc.conversation_id
            LEFT JOIN users u ON u.user_id = cc.user_id
            WHERE cc.circle_id = ?
        """
        return db.select(with: sql, arguments: [circleId])
    }
    
    public func replaceAllCircles(with circles: [Circle]) {
        db.write { db in
            try Circle.deleteAll(db)
            try circles.save(db)
        }
    }
    
    public func delete(circleId: String) {
        db.write { db in
            try Circle
                .filter(Circle.column(of: .circleId) == circleId)
                .deleteAll(db)
            try CircleConversation
                .filter(CircleConversation.column(of: .circleId) == circleId)
                .deleteAll(db)
        }
    }
    
    public func circles(of conversationId: String, userId: String?) -> [CircleItem] {
        let userIdCondition: String
        var arguments = [conversationId]
        if let userId = userId {
            userIdCondition = "OR cc.user_id = ?"
            arguments.append(userId)
        } else {
            userIdCondition = ""
        }
        let sql = """
            SELECT c.circle_id, c.name,
                (SELECT COUNT(*) FROM circle_conversations conv WHERE conv.circle_id = c.circle_id) as conversation_count
            FROM circles c
            INNER JOIN circle_conversations cc ON cc.circle_id = c.circle_id
            LEFT JOIN conversations conv ON cc.conversation_id = conv.conversation_id
            WHERE conv.conversation_id = ? \(userIdCondition)
            ORDER BY c.created_at ASC
        """
        return db.select(with: sql, arguments: StatementArguments(arguments))
    }
    
}
