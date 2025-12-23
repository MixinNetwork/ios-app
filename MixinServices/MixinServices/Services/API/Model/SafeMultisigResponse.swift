import Foundation

public struct SafeMultisigResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case assetID = "asset_id"
        case amount
        case sendersHash = "senders_hash"
        case sendersThreshold = "senders_threshold"
        case senders
        case receivers
        case signers
        case rawTransaction = "raw_transaction"
        case views
        case revokedBy = "revoked_by"
        case safe
    }
    
    public let requestID: String
    public let assetID: String
    public let amount: String
    public let sendersHash: String
    public let sendersThreshold: Int32
    public let senders: [String]
    public let receivers: [Receiver]
    public let signers: Set<String>
    public let rawTransaction: String
    public let views: [String]?
    public let revokedBy: String?
    public let safe: Safe?
    
}

extension SafeMultisigResponse {
    
    public struct Receiver: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case members
            case membersHash = "members_hash"
            case threshold
        }
        
        public let members: [String]
        public let membersHash: String
        public let threshold: Int32
        
    }
    
    public struct Safe: Decodable {
        
        public enum Operation: Decodable {
            
            enum CodingKeys: CodingKey {
                case transaction
                case recovery
            }
            
            case transaction(Transaction)
            case recovery(Recovery)
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let transaction = try container.decodeIfPresent(Transaction.self, forKey: .transaction) {
                    self = .transaction(transaction)
                } else if let recovery = try container.decodeIfPresent(Recovery.self, forKey: .recovery) {
                    self = .recovery(recovery)
                } else {
                    throw DecodingError.valueNotFound(
                        Operation.self, 
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Empty operation"
                        )
                    )
                }
            }
            
        }
        
        public struct Recovery: Decodable {
            public let address: String
            public let assets: [Asset]
        }
        
        public struct Asset: Decodable {
            
            enum CodingKeys: String, CodingKey {
                case name = "name"
                case symbol = "symbol"
                case iconURL = "icon_url"
                case priceUsd = "price_usd"
                case amount = "amount"
            }
            
            public let name: String
            public let symbol: String
            public let iconURL: String
            public let priceUsd: String
            public let amount: String
            
        }
        
        public struct Transaction: Decodable {
            
            enum CodingKeys: String, CodingKey {
                case assetID = "asset_id"
                case recipients = "recipients"
                case note = "note"
            }
            
            public let assetID: String
            public let recipients: [Recipient]
            public let note: String
            
        }
        
        public final class Recipient: Decodable {
            
            enum CodingKeys: CodingKey {
                case address
                case amount
            }
            
            public let address: String
            public let amount: Decimal
            
            public var label: String?
            
            required public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let address = try container.decode(String.self, forKey: .address)
                let amountString = try container.decode(String.self, forKey: .amount)
                guard let amount = Decimal(string: amountString, locale: .enUSPOSIX) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .amount,
                        in: container,
                        debugDescription: "Bad amount"
                    )
                }
                self.address = address
                self.amount = amount
            }
            
        }
        
        public let id: String
        public let name: String
        public let address: String
        public let role: UnknownableEnum<SafeRole>
        public let operation: Operation
        
    }
    
}
