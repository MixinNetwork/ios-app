import Foundation
import GRDB

public class MixinToken: Codable, Token, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case kernelAssetID = "kernel_asset_id"
        case symbol
        case name
        case iconURL = "icon_url"
        case btcPrice = "price_btc"
        case usdPrice = "price_usd"
        case chainID = "chain_id"
        case usdChange = "change_usd"
        case btcChange = "change_btc"
        case dust
        case confirmations
        case assetKey = "asset_key"
        case collectionHash = "collection_hash"
    }
    
    public static let databaseTableName = "tokens"
    
    public let assetID: String
    public let kernelAssetID: String
    public let symbol: String
    public let name: String
    public let iconURL: String
    public let btcPrice: String
    public let usdPrice: String
    public let chainID: String
    public let usdChange: String
    public let btcChange: String
    public let dust: String
    public let confirmations: Int
    public let assetKey: String
    public let collectionHash: String?
    
    public private(set) lazy var decimalBTCPrice = Decimal(string: btcPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: usdPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDChange = Decimal(string: usdChange, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalDust = Decimal(string: dust, locale: .enUSPOSIX) ?? 0
    
    public init(
        assetID: String, kernelAssetID: String, symbol: String, name: String, iconURL: String,
        btcPrice: String, usdPrice: String, chainID: String, usdChange: String,
        btcChange: String, dust: String, confirmations: Int, assetKey: String, collectionHash: String?
    ) {
        self.assetID = assetID
        self.kernelAssetID = kernelAssetID
        self.symbol = symbol
        self.name = name
        self.iconURL = iconURL
        self.btcPrice = btcPrice
        self.usdPrice = usdPrice
        self.chainID = chainID
        self.usdChange = usdChange
        self.btcChange = btcChange
        self.dust = dust
        self.confirmations = confirmations
        self.assetKey = assetKey
        self.collectionHash = collectionHash
    }
    
}

extension MixinToken: MaliciousDistinguishable {
    
    public var isMalicious: Bool {
        false
    }
    
}

extension MixinToken {
    
    public static let precision = 8
    public static let minimalAmount: Decimal = 0.000_000_01
    
    public var isNFT: Bool {
        !(collectionHash?.isEmpty ?? true)
    }
    
}
