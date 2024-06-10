import Foundation

public struct Web3ChainUpdate {
    
    public let chainID: String
    public let rpc: URL
    public let dapps: [Web3Dapp]
    
}

extension Web3ChainUpdate: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case rpc
        case dapps
    }
    
}
