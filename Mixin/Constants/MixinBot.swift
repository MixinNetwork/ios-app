import Foundation

struct MixinBot {
    
    static let teamMixin = MixinBot(name: "Team Mixin", id: "773e5e77-4107-45c2-b648-8fc722ed77f5")
    static let mixinBots = MixinBot(name: "Mixin Bots", id: "68ef7899-3e81-4b3d-8124-83ae652def89")
    static let mixinData = MixinBot(name: "Mixin Data", id: "96c1460b-c7c4-480a-a342-acaa73995a37")
    
    let name: String
    let id: String
    
}
