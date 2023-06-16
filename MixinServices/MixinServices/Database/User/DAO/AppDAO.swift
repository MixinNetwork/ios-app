import Foundation
import GRDB

public final class AppDAO: UserDatabaseDAO {
    
    public static let shared = AppDAO()
    
    internal static let sqlQueryColumns = "a.app_id, a.app_number, a.redirect_uri, u.full_name AS name, ifnull(a.category, '\(AppCategory.OTHER.rawValue)') AS category, a.icon_url, a.capabilites, a.resource_patterns, a.home_uri, a.creator_id, a.updated_at"
    
    public func getConversationBots(conversationId: String) -> [App] {
        let sql = """
        SELECT \(Self.sqlQueryColumns) FROM participants p, apps a, users u
        WHERE p.conversation_id = ? AND p.user_id = u.user_id AND a.app_id = u.app_id
        """
        return db.select(with: sql, arguments: [conversationId])
            .filter { (app: App) -> Bool in
                app.capabilities?.contains(ConversationCategory.GROUP.rawValue) ?? false
            }
    }
    
    public func getApp(ofUserId userId: String) -> App? {
        let sql = """
        SELECT \(Self.sqlQueryColumns) FROM apps a, users u
        WHERE u.user_id = ? AND a.app_id = u.app_id
        """
        return db.select(with: sql, arguments: [userId])
    }
    
    public func getApp(appId: String) -> App? {
        let sql = """
        SELECT \(Self.sqlQueryColumns) FROM apps a
        INNER JOIN users u ON a.app_id = u.app_id
        WHERE a.app_id = ?
        """
        return db.select(with: sql, arguments: [appId])
    }
    
    public func apps(limit: Int, after appId: String?) -> [App] {
        var sql = "SELECT * FROM apps"
        if let appId {
            sql += " WHERE ROWID > IFNULL((SELECT ROWID FROM apps WHERE app_id = '\(appId)'), 0)"
        }
        sql += " ORDER BY ROWID LIMIT ?"
        return db.select(with: sql, arguments: [limit])
    }
    
    public func appsCount() -> Int64 {
        let count: Int64? = db.select(with: "SELECT COUNT(*) FROM apps")
        return count ?? 0
    }
    
    public func save(app: App) {
        db.save(app)
    }
    
}
