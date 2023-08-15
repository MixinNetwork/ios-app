import Foundation

public struct MixinHost {
    
    public let index: Int
    public let blaze: String
    public let api: String
    
}

extension MixinHost: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.index == rhs.index
    }
    
}

extension MixinHost {
    
    public static var current: MixinHost {
        indexLock.lock()
        let host = all[currentIndex]
        indexLock.unlock()
        return host
    }
    
    public static let all = [
        MixinHost(
            index: 0,
            blaze: "mixin-blaze.zeromesh.net",
            api: "mixin-api.zeromesh.net"
        ),
        MixinHost(
            index: 1,
            blaze: "blaze.mixin.one",
            api: "api.mixin.one"
        ),
    ]
    
    private static let indexLock = NSLock()
    
    private static var currentIndex: Int = AppGroupUserDefaults.serverIndex
    
    public static func toggle(from host: MixinHost) {
        indexLock.lock()
        defer {
            indexLock.unlock()
        }
        guard host == all[currentIndex] else {
            return
        }
        var nextIndex = currentIndex + 1
        if nextIndex >= all.count {
            nextIndex = 0
        }
        currentIndex = nextIndex
        AppGroupUserDefaults.serverIndex = nextIndex
        Logger.general.info(category: "MixinHost", message: "Toggled server to \(all[nextIndex].api)")
    }
    
}
