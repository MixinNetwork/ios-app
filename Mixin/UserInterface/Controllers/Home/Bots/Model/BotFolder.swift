import UIKit

class BotFolder: BotItem {
    
    var id: String
    var name: String
    var pages: [[Bot]]
    
    init(id: String, name: String, pages: [[Bot]]) {
        self.id = id
        self.name = name
        self.pages = pages
    }
    
}

extension BotFolder: Equatable {
    
    static func == (lhs: BotFolder, rhs: BotFolder) -> Bool {
        return lhs === rhs
    }
    
}
