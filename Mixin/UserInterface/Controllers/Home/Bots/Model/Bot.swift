import UIKit

class Bot: BotItem {
    
    var id: String
    var app: HomeApp? {
        return HomeApp(id: id)
    }
    
    init(id: String) {
        self.id = id
    }
    
    func toDictionary() -> [String : Any] {
        return ["type": HomeAppItemType.app.rawValue, "id": id] as [String: Any]
    }

}

extension Bot: Equatable {
    
    static func == (lhs: Bot, rhs: Bot) -> Bool {
        return lhs === rhs
    }
    
}
