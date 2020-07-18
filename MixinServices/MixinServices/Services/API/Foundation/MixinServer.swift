import Foundation

public enum MixinServer {
    
    public static var webSocketHost: String {
        return all[MixinServer.serverIndex].0
    }
    
    public static var httpUrl: String {
        return all[MixinServer.serverIndex].1
    }
    
    private static let all = [
        ("mixin-blaze.zeromesh.net", "https://mixin-api.zeromesh.net/"),
        ("blaze.mixin.one", "https://api.mixin.one/")
    ]
    
    @Atomic(AppGroupUserDefaults.serverIndex)
    private static var serverIndex: Int
    
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
        var nextIndex = serverIndex + 1
        if nextIndex >= all.count {
            nextIndex = 0
        }
        serverIndex = nextIndex
        AppGroupUserDefaults.serverIndex = nextIndex
        Logger.write(log: "[MixinServer][ToggleIndex]...\(webSocketHost):\(httpUrl)", newSection: true)
    }
    
}
