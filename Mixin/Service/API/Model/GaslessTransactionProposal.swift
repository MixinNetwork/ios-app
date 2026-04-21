import Foundation
import MixinServices

struct GaslessTransactionProposal: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case payload = "payload"
    }
    
    enum Payload {
        case solana(Solana.Transaction)
        case evm(GaslessTransactionEVMPayload)
    }
    
    private static let supportedEVMChainID: Set<String> = [
        ChainID.ethereum, ChainID.polygon, ChainID.bnbSmartChain,
        ChainID.base, ChainID.arbitrumOne, ChainID.opMainnet
    ]
    
    let chainID: String
    let payload: Payload
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let chainID = try container.decode(String.self, forKey: .chainID)
        if chainID == ChainID.solana {
            let payload = try container.decode(String.self, forKey: .payload)
            guard let tx = Solana.Transaction(string: payload, encoding: .base64URL) else {
                throw DecodingError.dataCorruptedError(
                    forKey: CodingKeys.payload,
                    in: container,
                    debugDescription: "Solana tx decoding failed"
                )
            }
            self.chainID = chainID
            self.payload = .solana(tx)
        } else if Self.supportedEVMChainID.contains(chainID) {
            let payload = try container.decode(GaslessTransactionEVMPayload.self, forKey: .payload)
            self.chainID = chainID
            self.payload = .evm(payload)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: CodingKeys.chainID,
                in: container,
                debugDescription: "Unsupported chain_id"
            )
        }
    }
    
}
