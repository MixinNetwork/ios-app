import Foundation

struct GaslessTransaction {
    
    let broadcastTxHash: String?
    
}

extension GaslessTransaction: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case broadcastTxHash = "broadcast_tx_hash"
    }
    
}
