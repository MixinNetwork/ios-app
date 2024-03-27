import Foundation
import Starscream
import WalletConnectRelay

extension WebSocket: WebSocketConnecting {
    
}

struct StarscreamFactory: WebSocketFactory {
    
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
    
}
