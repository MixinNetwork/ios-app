import Foundation

public struct TIPGas {
    
    public let chainID: String
    public let safeGasPrice: String
    public let proposeGasPrice: String
    public let fastGasPrice: String
    public let gasLimit: String
    
}

extension TIPGas: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case safeGasPrice = "safe_gas_price"
        case proposeGasPrice = "propose_gas_price"
        case fastGasPrice = "fast_gas_price"
        case gasLimit = "gas_limit"
    }
    
}
