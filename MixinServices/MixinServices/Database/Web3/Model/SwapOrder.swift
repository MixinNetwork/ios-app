import Foundation
import GRDB

public struct SwapOrder {
    
    public enum State: String {
        case created
        case pending
        case success
        case failed
        case cancelling
        case cancelled
        case expired
    }
    
    public enum OrderType: String {
        case swap
        case limit
    }
    
    public struct Token: Decodable, MixinFetchableRecord {
        
        public enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case symbol
            case iconURL = "icon_url"
            case chainName = "chain_name"
        }
        
        public let assetID: String
        public let symbol: String
        public let iconURL: URL?
        public let chainName: String?
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.assetID = try container.decode(String.self, forKey: .assetID)
            self.symbol = try container.decode(String.self, forKey: .symbol)
            self.iconURL = URL(string: try container.decode(String.self, forKey: .iconURL))
            self.chainName = try container.decodeIfPresent(String.self, forKey: .chainName)
        }
        
    }
    
    public let orderID: String
    public let walletID: String
    public let userID: String
    public let payAssetID: String
    public let receiveAssetID: String
    public let payAmount: String
    public let receiveAmount: String?
    public let payTraceID: String?
    public let receiveTraceID: String?
    public let state: String
    public let createdAt: String
    public let orderType: String
    public let pendingAmount: String?
    public let filledReceiveAmount: String?
    public let expectedReceiveAmount: String?
    public let expiredAt: String?
    
}

extension SwapOrder: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case walletID = "wallet_id"
        case userID = "user_id"
        case payAssetID = "pay_asset_id"
        case receiveAssetID = "receive_asset_id"
        case payAmount = "pay_amount"
        case receiveAmount = "receive_amount"
        case payTraceID = "pay_trace_id"
        case receiveTraceID = "receive_trace_id"
        case state = "state"
        case createdAt = "created_at"
        case orderType = "order_type"
        case pendingAmount = "pending_amount"
        case filledReceiveAmount = "filled_receive_amount"
        case expectedReceiveAmount = "expected_receive_amount"
        case expiredAt = "expired_at"
    }
    
}

extension SwapOrder: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "orders"
    
}
