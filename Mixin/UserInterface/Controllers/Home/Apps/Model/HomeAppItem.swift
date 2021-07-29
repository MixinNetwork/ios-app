import Foundation

enum HomeAppItem {
    
    case app(HomeApp)
    case folder(HomeAppFolder)
    
    var app: HomeApp? {
        switch self {
        case let .app(app):
            return app
        default:
            return nil
        }
    }
    
    var folder: HomeAppFolder? {
        switch self {
        case let .folder(folder):
            return folder
        default:
            return nil
        }
    }
    
    init(app: HomeApp) {
        self = .app(app)
    }
    
    init(folder: HomeAppFolder) {
        self = .folder(folder)
    }
    
}

extension HomeAppItem: Equatable {
    
    static func == (lhs: HomeAppItem, rhs: HomeAppItem) -> Bool {
        switch (lhs, rhs) {
        case (.app(let one), .app(let another)):
            return one == another
        case (.folder(let one), .folder(let another)):
            return one == another
        default:
            return false
        }
    }
    
}
