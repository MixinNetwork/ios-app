import WCDBSwift

final class FavoriteAppsDAO {
    
    static let shared = FavoriteAppsDAO()
    
    private static let queryUsers = """
    SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at
    FROM users u
    LEFT JOIN favorite_apps ON favorite_apps.app_id = u.app_id
    WHERE favorite_apps.user_id = ?
    ORDER BY favorite_apps.created_at ASC
    """
    private static let queryApps = """
    SELECT \(AppDAO.sqlQueryColumns)
    FROM apps a
    INNER JOIN users u ON a.app_id = u.app_id
    LEFT JOIN favorite_apps fav ON fav.app_id = a.app_id
    WHERE fav.user_id = ?
    ORDER BY a.name ASC
    """
    
    func favoriteAppsOfUser(withId id: String) -> [App] {
        return MixinDatabase.shared.getCodables(on: App.Properties.all, sql: FavoriteAppsDAO.queryApps, values: [id])
    }
    
    func favoriteAppUsersOfUser(withId id: String) -> [User] {
        return MixinDatabase.shared.getCodables(on: User.Properties.all, sql: FavoriteAppsDAO.queryUsers, values: [id])
    }
    
    func setFavoriteApp(_ app: FavoriteApp) {
        MixinDatabase.shared.insertOrReplace(objects: [app])
    }
    
    func unfavoriteApp(of id: String) {
        let condition = FavoriteApp.Properties.userId == AccountAPI.shared.accountUserId
            && FavoriteApp.Properties.appId == id
        MixinDatabase.shared.delete(table: FavoriteApp.tableName, condition: condition)
    }
    
    func updateFavoriteApps(_ apps: [FavoriteApp], forUserWith userId: String) {
        let appIds = apps.compactMap({ $0.appId })
        MixinDatabase.shared.transaction { (db) in
            try db.delete(fromTable: FavoriteApp.tableName, where: FavoriteApp.Properties.userId == userId && FavoriteApp.Properties.appId.notIn(appIds))
            try db.insertOrReplace(objects: apps, intoTable: FavoriteApp.tableName)
        }
    }
    
}
