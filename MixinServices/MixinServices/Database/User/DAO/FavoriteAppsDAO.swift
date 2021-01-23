import GRDB

public final class FavoriteAppsDAO: UserDatabaseDAO {
    
    public static let shared = FavoriteAppsDAO()
    
    public func favoriteAppsOfUser(withId id: String) -> [App] {
        let sql = """
        SELECT \(AppDAO.sqlQueryColumns)
        FROM apps a
        INNER JOIN users u ON a.app_id = u.app_id
        LEFT JOIN favorite_apps fav ON fav.app_id = a.app_id
        WHERE fav.user_id = ?
        ORDER BY a.name ASC
        """
        return db.select(with: sql, arguments: [id])
    }
    
    public func favoriteAppUsersOfUser(withId id: String) -> [User] {
        let sql = """
        SELECT u.user_id, u.full_name, u.biography, u.identity_number, u.avatar_url, u.phone, u.is_verified, u.mute_until, u.app_id, u.relationship, u.created_at, u.is_scam
        FROM users u
        LEFT JOIN favorite_apps ON favorite_apps.app_id = u.app_id
        WHERE favorite_apps.user_id = ?
        ORDER BY favorite_apps.created_at ASC
        """
        return db.select(with: sql, arguments: [id])
    }

    public func setFavoriteApp(_ app: FavoriteApp) {
        db.save(app)
    }

    public func unfavoriteApp(of id: String) {
        let condition = FavoriteApp.column(of: .userId) == myUserId
            && FavoriteApp.column(of: .appId) == id
        db.delete(FavoriteApp.self, where: condition)
    }
    
    public func updateFavoriteApps(_ apps: [FavoriteApp], forUserWith userId: String) {
        let appIds = apps.compactMap({ $0.appId })
        db.write { (db) -> Void in
            try FavoriteApp
                .filter(FavoriteApp.column(of: .userId) == userId && !appIds.contains(FavoriteApp.column(of: .appId)))
                .deleteAll(db)
            try apps.save(db)
        }
    }
    
}
