import Foundation
import MixinServices

enum HomeApp {
    
    case embedded(EmbeddedApp)
    case external(User)
    
    var id: String {
        switch self {
        case .embedded(let app):
            return app.id
        case .external(let user):
            assert(user.appId != nil)
            return user.appId ?? ""
        }
    }
    
    init?(id: String) {
        if let app = EmbeddedApp.all.first(where: { $0.id == id }) {
            self = .embedded(app)
        } else if var user = UserDAO.shared.getUser(withAppId: id) {
            user.app = AppDAO.shared.getApp(appId: id)
            self = .external(user)
        } else {
            return nil
        }
    }
    
}

extension HomeApp: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
}
