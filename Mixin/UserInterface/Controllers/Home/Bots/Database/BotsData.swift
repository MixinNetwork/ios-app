import Foundation

enum BotsType {
    case folder
    case bot
}

struct BotsItem {
    
}

struct Bots {
    var type: BotsType
    var bots: [[Bots]]
    var name: String
    var id: String
    
    /**
     type = bot
        name: bots[0][0].name
        bots:
     
     type = folder
        name = folderName
        bots: [[]]
     
     */
}

struct BotsData {
    var pages: [[Bots]]?
}

