import Foundation

class AppModel: AppItem {
    
    var id: String
    var app: HomeApp
    
    init(id: String, app: HomeApp) {
        self.id = id
        self.app = app
    }
    
    func toDictionary() -> [String : Any] {
        return ["type": HomeAppItemType.app.rawValue, "id": id] as [String: Any]
    }
    
}

extension AppModel: Equatable {
    
    static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        return lhs === rhs
    }
    
}
