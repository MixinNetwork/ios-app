import Foundation
import GRDB

public class Token: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
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
    
    public private(set) lazy var decimalBTCPrice = Decimal(string: btcPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: usdPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDChange = Decimal(string: usdChange, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalDust = Decimal(string: dust, locale: .enUSPOSIX) ?? 0
    
    public init(
        assetID: String, kernelAssetID: String, symbol: String, name: String, iconURL: String,
        btcPrice: String, usdPrice: String, chainID: String, usdChange: String,
        btcChange: String, dust: String, confirmations: Int, assetKey: String
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
    }
    
}

extension Token {
    
    public var usesTag: Bool {
        assetID == AssetID.xrp
    }
    
    public var isBitcoinChain: Bool {
        chainID == ChainID.bitcoin
    }
    
    public var isEOSChain: Bool {
        chainID == ChainID.eos
    }
    
    public var isERC20: Bool {
        chainID == ChainID.ethereum
    }
    
}

extension Token {
    
    public var isDepositSupported: Bool {
        !AssetID.depositNotSupported.contains(assetID)
    }
    
}

extension Token {
    
    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = .enUSPOSIX
        formatter.usesGroupingSeparator = false
        return formatter
    }()
    
    public static func amountString(from decimal: Decimal) -> String {
        amountFormatter.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
    
}