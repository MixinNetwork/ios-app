import UIKit

enum HomeAppItemType: Int {
    case app
    case folder
}

protocol BotItem: AnyObject {
    
    func toDictionary() -> [String: Any]
    
}
