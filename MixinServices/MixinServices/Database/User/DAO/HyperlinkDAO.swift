import GRDB

public final class HyperlinkDAO: UserDatabaseDAO {
    
    public static let shared = HyperlinkDAO()
    
    public func insert(_ hyperlink: Hyperlink, database: GRDB.Database) throws {
        try hyperlink.save(database)
    }
    
    public func hyperlinks(conversationId: String) -> [HyperlinkItem] {
        let sql = """
        SELECT h.hyperlink, h.site_description, h.site_image, h.site_name, h.site_title, m.created_at
        FROM hyperlinks h
        INNER JOIN messages m ON h.hyperlink = m.hyperlink
        WHERE m.conversation_id = ? AND m.category IN ('SIGNAL_TEXT', 'PLAIN_TEXT', 'ENCRYPTED_TEXT')
        ORDER BY m.created_at DESC
        """
        return db.select(with: sql, arguments: [conversationId])
    }
    
}
