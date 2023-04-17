import Foundation
import Network
import MixinServices

enum LocalNetwork {
    
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        if #available(iOS 14.0, *) {
            guard let ip = IPAddress.currentWiFiIPAddress() else {
                completion(false)
                return
            }
            let host = NWEndpoint.Host(ip)
            let port = NWEndpoint.Port(integerLiteral: NetworkPort.randomAvailablePort())
            let endPoint = NWEndpoint.hostPort(host: host, port: port)
            let connection = NWConnection(to: endPoint, using: .tcp)
            if AppGroupUserDefaults.isLocalNetworkTriggered {
                connection.stateUpdateHandler = { newState in
                    switch newState {
                    case .waiting(let error):
                        if error == .posix(.ENETDOWN) {
                            completion(false)
                        } else {
                            completion(true)
                        }
                        connection.stateUpdateHandler = nil
                        connection.forceCancel()
                    case .ready, .failed:
                        connection.stateUpdateHandler = nil
                        connection.forceCancel()
                        completion(true)
                    default:
                        break
                    }
                }
            } else {
                AppGroupUserDefaults.isLocalNetworkTriggered = true
            }
            connection.start(queue: .main)
        } else {
            completion(true)
        }
    }
    
}
