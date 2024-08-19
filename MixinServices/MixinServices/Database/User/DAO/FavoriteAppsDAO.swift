import GRDB

public final class FavoriteAppsDAO: UserDatabaseDAO {
    
    public static let shared = FavoriteAppsDAO()
    
    public static let favoriteAppsDidChangeNotification = Notification.Name(rawValue: "one.mixin.services.FavoriteAppsDAO.FavoriteAppsDidChange")

    public func favoriteAppsOfUser(withId id: String) -> [App] {
        let sql = """
        SELECT \(AppDAO.sqlQueryColumns)
        FROM favorite_apps fa
        INNER JOIN apps a ON fa.app_id = a.app_id
        INNER JOIN users u ON fa.app_id = u.app_id
        WHERE fa.user_id = ?
        ORDER BY fa.created_at ASC
        """
        return db.select(with: sql, arguments: [id])
    }
    
    public func favoriteAppUsersOfUser(withId id: String) -> [User] {
        let sql = """
        SELECT u.*
        FROM users u
            LEFT JOIN favorite_apps ON favorite_apps.app_id = u.app_id
        WHERE favorite_apps.user_id = ?
        ORDER BY favorite_apps.created_at ASC
        """
        return db.select(with: sql, arguments: [id])
    }

    public func setFavoriteApp(_ app: FavoriteApp) {
        db.save(app) { _ in
            NotificationCenter.default.post(onMainThread: Self.favoriteAppsDidChangeNotification, object: nil)
        }
    }

    public func unfavoriteApp(of id: String) {
        let condition = FavoriteApp.column(of: .userId) == myUserId
            && FavoriteApp.column(of: .appId) == id
        db.delete(FavoriteApp.self, where: condition) { _ in
            NotificationCenter.default.post(onMainThread: Self.favoriteAppsDidChangeNotification, object: nil)
        }
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
