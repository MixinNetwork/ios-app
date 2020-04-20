import Foundation
import WCDBSwift

public final class AppDAO {
    
    public static let shared = AppDAO()

    static let sqlQueryColumns = "a.app_id, a.app_number, a.redirect_uri, u.full_name, ifnull(a.category, '\(AppCategory.OTHER)'), a.icon_url, a.capabilites, a.resource_patterns, a.home_uri, a.creator_id"
    static let sqlQueryApps = """
    SELECT \(sqlQueryColumns) FROM participants p, apps a, users u
    WHERE p.conversation_id = ? AND p.user_id = u.user_id AND a.app_id = u.app_id
    """
    static let sqlQueryAppsByUser = """
    SELECT \(sqlQueryColumns) FROM apps a, users u
    WHERE u.user_id = ? AND a.app_id = u.app_id
    """
    static let sqlQueryAppById = """
    SELECT \(sqlQueryColumns) FROM apps a
    INNER JOIN users u ON a.app_id = u.app_id
    WHERE a.app_id = ?
    """
    
    public func getConversationBots(conversationId: String) -> [App] {
        return MixinDatabase.shared.getCodables(sql: AppDAO.sqlQueryApps, values: [conversationId]).filter({ (app) -> Bool in
            return app.capabilities?.contains(ConversationCategory.GROUP.rawValue) ?? false
        })
    }
    
    public func getApp(ofUserId userId: String) -> App? {
        return MixinDatabase.shared.getCodables(sql: AppDAO.sqlQueryAppsByUser, values: [userId]).first
    }

    public func getApp(appId: String) -> App? {
        return MixinDatabase.shared.getCodables(sql: AppDAO.sqlQueryAppById, values: [appId]).first
    }
}
