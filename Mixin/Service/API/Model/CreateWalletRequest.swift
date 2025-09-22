import Foundation
import MixinServices

struct CreateWalletRequest: Encodable {
    
    enum SigningError: Error {
        case makeContent
    }
    
    struct Address: Encodable {
        
        enum CodingKeys: String, CodingKey {
            case destination
            case chainID = "chain_id"
            case path
            case signature
            case timestamp
        }
        
        let destination: String
        let chainID: String
        let path: String?
        let signature: String?
        let timestamp: String?
        
        init(
            destination: String,
            chainID: String,
            path: String?,
            signature: String? = nil,
            timestamp: String? = nil
        ) {
            self.destination = destination
            self.chainID = chainID
            self.path = path
            self.signature = signature
            self.timestamp = timestamp
        }
        
        func sign(userID: String, sign: (Data) throws -> String) throws -> Address {
            let timestampInSeconds = floor(Date().timeIntervalSince1970)
            let timestamp = DateFormatter.iso8601Full.string(
                from: Date(timeIntervalSince1970: timestampInSeconds)
            )
            let signingContent = """
            \(destination)
            \(userID)
            \(Int(timestampInSeconds))
            """
            guard let data = signingContent.data(using: .utf8) else {
                throw SigningError.makeContent
            }
            let signature = try sign(data)
            return Address(
                destination: destination,
                chainID: chainID,
                path: path,
                signature: signature,
                timestamp: timestamp
            )
        }
        
    }
    
    let name: String
    let category: Web3Wallet.Category
    let addresses: [Address]
    
}
