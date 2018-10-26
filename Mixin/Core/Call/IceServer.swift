import Foundation
import WebRTC

extension RTCIceServer {
    
    static let fallback = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
    
    static var sharedServers: [RTCIceServer] = {
        var servers = loadIceServer()
        servers.append(.fallback)
        return servers
    }()
    
    private static func loadIceServer() -> [RTCIceServer] {
        return []
    }
    
}
