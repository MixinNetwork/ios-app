import UIKit

class Bot: BotItem {
    
    var id: String
    var name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
}

extension Bot: Equatable {
    
    static func == (lhs: Bot, rhs: Bot) -> Bool {
        return lhs === rhs
    }
    
}
