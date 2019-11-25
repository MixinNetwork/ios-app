import Foundation

enum MixinServer {
    
    static var webSocket: URL {
        return current.ws
    }
    
    static var http: String {
        return current.http
    }
    
    private static let key = "server_index"
    private static let lock = NSLock()
    
    private static let all = [
        (URL(string: "wss://mixin-blaze.zeromesh.net")!, "https://mixin-api.zeromesh.net/"),
        (URL(string: "wss://blaze.mixin.one")!, "https://api.mixin.one/")
    ]
    
    private static var current: (ws: URL, http: String) {
        lock.lock()
        let index = UserDefaults.standard.integer(forKey: key)
        lock.unlock()
        if index >= all.startIndex && index < all.endIndex {
            return all[index]
        } else {
            return all[0]
        }
    }
    
    static func toggle(currentWebSocketUrl url: URL) {
        guard url == webSocket else {
            return
        }
        toggleIndex()
    }
    
    static func toggle(currentHttpAddress address: String) {
        guard address == http else {
            return
        }
        toggleIndex()
    }
    
    private static func toggleIndex() {
        lock.lock()
        var index = UserDefaults.standard.integer(forKey: key)
        index += 1
        if index == all.endIndex {
            index = all.startIndex
        }
        UserDefaults.standard.set(index, forKey: key)
        lock.unlock()
    }
    
}
