import Foundation
import GRDB

public struct SwapOrderItem {
    
    public let orderID: String
    
    public let payAssetID: String
    public let receiveAssetID: String
    
    public let paySymbol: String
    public let receiveSymbol: String
    
    public let payIconURL: URL?
    public let receiveIconURL: URL?
    
    public let payChainName: String
    public let receiveChainName: String
    
    public let payAmount: Decimal
    public let receiveAmount: Decimal
    
    public let createdAt: String
    public let createdAtDate: Date?
    public let state: SwapOrder.State?
    public let type: SwapOrder.OrderType?
    
    public var exchangingSymbolRepresentation: String {
        paySymbol + " → " + receiveSymbol
    }
    
}

extension SwapOrderItem: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.orderID == rhs.orderID
    }
    
}

extension SwapOrderItem: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        
        case payAssetID = "pay_asset_id"
        case receiveAssetID = "receive_asset_id"
        
        case paySymbol = "pay_symbol"
        case receiveSymbol = "receive_symbol"
        
        case payIcon = "pay_icon"
        case receiveIcon = "receive_icon"
        
        case payChainName = "pay_chain_name"
        case receiveChainName = "receive_chain_name"
        
        case payAmount = "pay_amount"
        case receiveAmount = "receive_amount"
        
        case createdAt = "created_at"
        case state
        case type = "order_type"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderID = try container.decode(String.self, forKey: .orderID)
        
        payAssetID = try container.decode(String.self, forKey: .payAssetID)
        receiveAssetID = try container.decode(String.self, forKey: .receiveAssetID)
        
        paySymbol = try container.decodeIfPresent(String.self, forKey: .paySymbol) ?? ""
        receiveSymbol = try container.decodeIfPresent(String.self, forKey: .receiveSymbol) ?? ""
        
        payIconURL = if let string = try container.decodeIfPresent(String.self, forKey: .payIcon) {
            URL(string: string)
        } else {
            nil
        }
        receiveIconURL = if let string = try container.decodeIfPresent(String.self, forKey: .receiveIcon) {
            URL(string: string)
        } else {
            nil
        }
        
        payChainName = try container.decodeIfPresent(String.self, forKey: .payChainName) ?? ""
        receiveChainName = try container.decodeIfPresent(String.self, forKey: .receiveChainName) ?? ""
        
        payAmount = Decimal(string: try container.decode(String.self, forKey: .payAmount), locale: .enUSPOSIX) ?? 0
        receiveAmount = Decimal(string: try container.decode(String.self, forKey: .receiveAmount), locale: .enUSPOSIX) ?? 0
        
        createdAt = try container.decode(String.self, forKey: .createdAt)
        createdAtDate = DateFormatter.iso8601Full.date(from: createdAt)
        state = SwapOrder.State(rawValue: try container.decode(String.self, forKey: .state))
        type = SwapOrder.OrderType(rawValue: try container.decode(String.self, forKey: .type))
    }
    
}

extension SwapOrderItem: TableRecord {
    
    public static let databaseTableName = "swap_orders"
    
}
