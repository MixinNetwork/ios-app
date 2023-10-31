import Foundation
import GRDB

public class Token: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case kernelAssetID = "kernel_asset_id"
        case symbol
        case name
        case iconUrl = "icon_url"
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case chainId = "chain_id"
        case changeUsd = "change_usd"
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
    public let iconUrl: String
    public let priceBtc: String
    public let priceUsd: String
    public let chainId: String
    public let changeUsd: String
    public let btcChange: String
    public let dust: String
    public let confirmations: Int
    public let assetKey: String
    
    public private(set) lazy var decimalBTCPrice = Decimal(string: priceBtc, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: priceUsd, locale: .enUSPOSIX) ?? 0
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
        self.iconUrl = iconURL
        self.priceBtc = btcPrice
        self.priceUsd = usdPrice
        self.chainId = chainID
        self.changeUsd = usdChange
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
        chainId == ChainID.bitcoin
    }
    
    public var isEOSChain: Bool {
        chainId == ChainID.eos
    }
    
    public var isERC20: Bool {
        chainId == ChainID.ethereum
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
