import Foundation

struct Web3ChainUpdate {
    
    let chainID: String
    let rpcURLs: [String]
    let dapps: [Web3Dapp]
    
}

extension Web3ChainUpdate: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case rpcURLs = "rpc_urls"
        case dapps
    }
    
}
