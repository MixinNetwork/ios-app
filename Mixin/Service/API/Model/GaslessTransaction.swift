import Foundation
import MixinServices

struct GaslessTransaction {
    
    enum State: String {
        case pending
        case processing
        case done
        case failed
    }
    
    let state: UnknownableEnum<State>
    let broadcastTxHash: String?
    
}

extension GaslessTransaction: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case state = "state"
        case broadcastTxHash = "broadcast_tx_hash"
    }
    
}
