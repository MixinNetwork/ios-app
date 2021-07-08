import UIKit

class AppModel: AppItem {
    
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

extension AppModel: Equatable {
    
    static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        return lhs === rhs
    }
    
}

extension AppModel: CustomDebugStringConvertible {
    
    var debugDescription: String {
        let memoryAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
        return "<App: \(memoryAddress)> - \(id)"
    }
    
}
