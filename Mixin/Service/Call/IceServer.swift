import Foundation
import WebRTC
import MixinServices

extension RTCIceServer {
    
    static var sharedServers: [RTCIceServer] {
        return loadIceServer()
    }
        
    private static func loadIceServer() -> [RTCIceServer] {
        repeat {
            switch CallAPI.turn() {
            case let .success(servers):
                return servers.map({ RTCIceServer(urlStrings: [$0.url], username: $0.username, credential: $0.credential) })
            case let .failure(error):
                Logger.write(error: error)
                repeat {
                    Thread.sleep(forTimeInterval: 2)
                } while LoginManager.shared.isLoggedIn && !MixinService.isStopProcessMessages && !ReachabilityManger.shared.isReachable
            }
        } while LoginManager.shared.isLoggedIn
        return []
    }
    
}
