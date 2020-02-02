import Foundation
import WCDBSwift

public struct Asset: BaseCodable {
    
    public static let tableName: String = "assets"
    public static let topAssetsTableName = "top_assets"
    
    public let assetId: String
    public let type: String
    public let symbol: String
    public let name: String
    public let iconUrl: String
    public let balance: String
    public let destination: String
    public let tag: String
    public let priceBtc: String
    public let priceUsd: String
    public let changeUsd: String
    public let chainId: String
    public let confirmations: Int
    public let assetKey: String
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = Asset
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                assetId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
        case assetId = "asset_id"
        case type
        case symbol
        case name
        case iconUrl = "icon_url"
        case balance
        case destination
        case tag
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case changeUsd = "change_usd"
        case chainId = "chain_id"
        case confirmations
        case assetKey = "asset_key"
        
    }
    
    public init(assetId: String, type: String, symbol: String, name: String, iconUrl: String, balance: String, destination: String, tag: String, priceBtc: String, priceUsd: String, changeUsd: String, chainId: String, confirmations: Int, assetKey: String) {
        self.assetId = assetId
        self.type = type
        self.symbol = symbol
        self.name = name
        self.iconUrl = iconUrl
        self.balance = balance
        self.destination = destination
        self.tag = tag
        self.priceBtc = priceBtc
        self.priceUsd = priceUsd
        self.changeUsd = changeUsd
        self.chainId = chainId
        self.confirmations = confirmations
        self.assetKey = assetKey
    }
    
    public init(item: AssetItem) {
        self.init(assetId: item.assetId,
                  type: item.type,
                  symbol: item.symbol,
                  name: item.name,
                  iconUrl: item.iconUrl,
                  balance: item.balance,
                  destination: item.destination,
                  tag: item.tag,
                  priceBtc: item.priceBtc,
                  priceUsd: item.priceUsd,
                  changeUsd: item.changeUsd,
                  chainId: item.chainId,
                  confirmations: item.confirmations,
                  assetKey: item.assetKey)
    }
    
}
