import Foundation

enum MixinServer {
    
    static var webSocketUrl: URL {
        return all[MixinServer.serverIndex].0
    }
    
    static var httpUrl: String {
        return all[MixinServer.serverIndex].1
    }
    
    private static let key = "server_index"
    
    private static let all = [
        (URL(string: "wss://mixin-blaze.zeromesh.net")!, "https://mixin-api.zeromesh.net/"),
        (URL(string: "wss://blaze.mixin.one")!, "https://api.mixin.one/")
    ]

    private static var serverIndex = UserDefaults.standard.integer(forKey: key)
    
    static func toggle(currentWebSocketUrl url: URL) {
        guard url != webSocketUrl else {
            return
        }
        toggleIndex()
    }
    
    static func toggle(currentHttpUrl url: String) {
        guard url != httpUrl else {
            return
        }
        toggleIndex()
    }
    
    private static func toggleIndex() {
        var nextIndex = serverIndex + 1
        if nextIndex >= all.count {
            nextIndex = 0
        }
        serverIndex = nextIndex
        UserDefaults.standard.set(nextIndex, forKey: key)
    }
    
}
