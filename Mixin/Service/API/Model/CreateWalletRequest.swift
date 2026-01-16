import Foundation
import MixinServices

protocol CreateWalletRequest: Encodable {
    
}

struct CreateWatchWalletRequest: CreateWalletRequest {
    
    struct Address: Encodable {
        
        enum CodingKeys: String, CodingKey {
            case destination
            case chainID = "chain_id"
            case path
        }
        
        let destination: String
        let chainID: String
        let path: String?
        
    }
    
    let name: String
    let category = "watch_address"
    let addresses: [Address]
    
}

struct CreateSigningWalletRequest: CreateWalletRequest {
    
    enum SigningError: Error {
        case makeContent
    }
    
    enum Category: String, Encodable {
        case classic
        case importedMnemonic = "imported_mnemonic"
        case importedPrivateKey = "imported_private_key"
    }
    
    struct SignedAddress: Encodable {
        
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
        let signature: String
        let timestamp: String
        
        init(
            destination: String,
            chainID: String,
            path: String?,
            userID: String,
            sign: (String) throws -> String,
        ) throws {
            let timestampInSeconds = floor(Date().timeIntervalSince1970)
            let timestamp = DateFormatter.iso8601Full.string(
                from: Date(timeIntervalSince1970: timestampInSeconds)
            )
            let message = """
            \(destination)
            \(userID)
            \(Int(timestampInSeconds))
            """
            let signature = try sign(message)
            
            self.destination = destination
            self.chainID = chainID
            self.path = path
            self.signature = signature
            self.timestamp = timestamp
        }
        
        init(
            destination: String,
            chainID: String,
            path: String?,
            userID: String,
            sign: (Data) throws -> String,
        ) throws {
            try self.init(
                destination: destination,
                chainID: chainID,
                path: path,
                userID: userID
            ) { message in
                if let data = message.data(using: .utf8) {
                    return try sign(data)
                } else {
                    throw SigningError.makeContent
                }
            }
        }
        
    }
    
    let name: String
    let category: Category
    let addresses: [SignedAddress]
    
}
