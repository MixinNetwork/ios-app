import Foundation
import WebRTC
import MixinServices

extension RTCIceServer {
    
    static var sharedServers: [RTCIceServer] {
        return loadIceServer()
    }
    
    private static let semaphore = DispatchSemaphore(value: 0)
    private static let iceServerLoadingTimeoutInterval = DispatchTimeInterval.seconds(3)
    
    private static func loadIceServer() -> [RTCIceServer] {
        var output = [TurnServer]()
        CallAPI.shared.turn { (result) in
            switch result {
            case .success(let servers):
                output = servers
            case .failure(let error):
                Reporter.report(error: error)
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + iceServerLoadingTimeoutInterval)
        return output.map({ RTCIceServer(urlStrings: [$0.url], username: $0.username, credential: $0.credential) })
    }
    
}
