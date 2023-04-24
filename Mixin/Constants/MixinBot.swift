import Foundation

enum MixinBot {
    
    case teamMixin
    case mixinBots
    case mixinData
    
    var name: String {
        switch self {
        case .teamMixin:
            return "Team Mixin"
        case .mixinBots:
            return "Mixin Bots"
        case .mixinData:
            return "Mixin Data"
        }
    }
    
    var userId: String {
        switch self {
        case .teamMixin:
            return "773e5e77-4107-45c2-b648-8fc722ed77f5"
        case .mixinBots:
            return "68ef7899-3e81-4b3d-8124-83ae652def89"
        case .mixinData:
            return "96c1460b-c7c4-480a-a342-acaa73995a37"
        }
    }
    
}
