import Foundation
import MixinServices

enum HomeApp {
    
    case embedded(EmbeddedHomeApp)
    case external(User)
    
    var id: Any {
        switch self {
        case .embedded(let app):
            return app.id
        case .external(let user):
            assert(user.appId != nil)
            return user.appId ?? ""
        }
    }
    
    init?(id: Any) {
        if let id = id as? Int, id < EmbeddedHomeApp.all.count {
            let app = EmbeddedHomeApp.all[id]
            self = .embedded(app)
        } else if let id = id as? String, var user = UserDAO.shared.getUser(withAppId: id) {
            user.app = AppDAO.shared.getApp(appId: id)
            self = .external(user)
        } else {
            return nil
        }
    }
    
}

extension HomeApp: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        if case let .embedded(lApp) = lhs, case let .embedded(rApp) = rhs {
            return lApp.id == rApp.id
        } else if case let .external(lUser) = lhs, case let .external(rUser) = rhs {
            return lUser.userId == rUser.userId
        } else {
            return false
        }
    }
    
}
