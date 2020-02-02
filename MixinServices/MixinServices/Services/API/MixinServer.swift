import Foundation

public enum MixinServer {
    
    public static var webSocketHost: String {
        return all[MixinServer.serverIndex.value].0
    }
    
    public static var httpUrl: String {
        return all[MixinServer.serverIndex.value].1
    }
    
    private static let all = [
        ("mixin-blaze.zeromesh.net", "https://mixin-api.zeromesh.net/"),
        ("blaze.mixin.one", "https://api.mixin.one/")
    ]
    
    private static var serverIndex = Atomic<Int>(AppGroupUserDefaults.serverIndex)
    
    public static func toggle(currentWebSocketHost host: String?) {
        guard host == webSocketHost else {
            return
        }
        toggleIndex()
    }
    
    public static func toggle(currentHttpUrl url: String) {
        guard url == httpUrl else {
            return
        }
        toggleIndex()
    }
    
    private static func toggleIndex() {
        var nextIndex = serverIndex.value + 1
        if nextIndex >= all.count {
            nextIndex = 0
        }
        serverIndex.value = nextIndex
        AppGroupUserDefaults.serverIndex = nextIndex
    }
    
}
