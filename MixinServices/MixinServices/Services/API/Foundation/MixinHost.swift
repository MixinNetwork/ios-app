import Foundation

public enum MixinHost {
    
    public static var webSocket: String {
        return all[MixinHost.serverIndex].0
    }
    
    public static var http: String {
        return all[MixinHost.serverIndex].1
    }
    
    public static let all = [
        ("mixin-blaze.zeromesh.net", "mixin-api.zeromesh.net"),
        ("blaze.mixin.one", "api.mixin.one")
    ]
    
    @Synchronized(value: AppGroupUserDefaults.serverIndex)
    private static var serverIndex: Int
    
    public static func toggle(currentWebSocketHost host: String?) {
        guard host == webSocket else {
            return
        }
        toggleIndex()
    }
    
    public static func toggle(currentHttpHost host: String) {
        guard host == http else {
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
        Logger.write(log: "[MixinHost][ToggleIndex]...\(webSocket):\(http)", newSection: true)
    }
    
}
