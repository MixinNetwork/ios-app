import Foundation
import WCDBSwift

final class AppDAO {

    static let shared = AppDAO()
    static let sqlQueryColumns = "a.app_id, a.app_number, a.redirect_uri, u.full_name, a.icon_url, a.capabilites, a.app_secret, a.home_uri, a.creator_id"
    static let sqlQueryApps = """
        SELECT \(sqlQueryColumns) FROM participants p, apps a
        LEFT JOIN users u ON a.app_id = u.app_id
        WHERE p.conversation_id = ? AND p.user_id = u.user_id
    """
    static let sqlQueryAppsByUser = """
        SELECT \(sqlQueryColumns) FROM apps a
        LEFT JOIN users u ON a.app_id = u.app_id
        WHERE u.user_id = ?
    """
    
    func getConversationBots(conversationId: String) -> [App] {
        return MixinDatabase.shared.getCodables(sql: AppDAO.sqlQueryApps, values: [conversationId]).filter({ (app) -> Bool in
            return app.capabilities?.contains(ConversationCategory.GROUP.rawValue) ?? false
        })
    }

    func getApp(ofUserId userId: String) -> App? {
        return MixinDatabase.shared.getCodables(sql: AppDAO.sqlQueryAppsByUser, values: [userId]).first
    }
    
}
