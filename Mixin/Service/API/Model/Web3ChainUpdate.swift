import Foundation

struct Web3ChainUpdate {
    
    let chainID: String
    let rpc: URL
    let dapps: [Web3Dapp]
    
}

extension Web3ChainUpdate: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case rpc
        case dapps
    }
    
}
