import UIKit

enum HomeAppItemType: Int {
    case app
    case folder
}

protocol AppItem: AnyObject {
    
    func toDictionary() -> [String: Any]
    
}
