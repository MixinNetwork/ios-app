import UIKit

class BotFolder: BotItem {
    
    var name: String
    var pages: [[Bot]]
    var isNewFolder = false

    init(name: String, pages: [[Bot]]) {
        self.name = name
        self.pages = pages
    }
    
    func toDictionary() -> [String : Any] {
        let apps = pages.map { page -> [[String : Any]] in
            return page.map { $0.toDictionary() }
        }
        return ["type": HomeAppItemType.folder.rawValue, "name": name, "apps": apps]
    }
    
}

extension BotFolder: Equatable {
    
    static func == (lhs: BotFolder, rhs: BotFolder) -> Bool {
        return lhs === rhs
    }
    
}
