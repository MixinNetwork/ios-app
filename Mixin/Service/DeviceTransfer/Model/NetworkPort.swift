import Foundation
import Network

enum NetworkPort {
    
    static func randomAvailablePort() -> UInt16 {
        var port: UInt16 = 0
        while true {
            port = UInt16(arc4random_uniform(64512) + 1024)
            let port = NWEndpoint.Port(integerLiteral: port)
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            if let listener = try? NWListener(using: parameters, on: port) {
                listener.cancel()
                break
            } else {
                continue
            }
        }
        return port
    }
    
}
