import Foundation
import GRDB

public class Web3Token: Codable, Token, ValuableToken, ChangeReportingToken {
    
    public enum AssetKey {
        public static let sol = "11111111111111111111111111111111"
        public static let wrappedSOL = "So11111111111111111111111111111111111111112"
        public static let eth = "0x0000000000000000000000000000000000000000"
    }
    
    enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case assetID = "asset_id"
        case chainID = "chain_id"
        case assetKey = "asset_key"
        case kernelAssetID = "kernel_asset_id"
        case symbol
        case name
        case precision
        case iconURL = "icon_url"
        case amount
        case usdPrice = "price_usd"
        case usdChange = "change_usd"
    }
    
    public let walletID: String
    public let assetID: String
    public let chainID: String
    public let assetKey: String
    public let kernelAssetID: String
    public let symbol: String
    public let name: String
    public let precision: Int16
    public let iconURL: String
    public let amount: String
    public let usdPrice: String
    public let usdChange: String
    
    public private(set) lazy var decimalBalance = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    public private(set) lazy var decimalUSDPrice = Decimal(string: usdPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDChange = (Decimal(string: usdChange, locale: .enUSPOSIX) ?? 0) / 100
    
    public private(set) lazy var localizedUSDChange = localizeUSDChange()
    public private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    public private(set) lazy var localizedBalanceWithSymbol = localizeBalanceWithSymbol()
    public private(set) lazy var estimatedFiatMoneyBalance = estimateFiatMoneyBalance()
    
    public var chainTag: String? {
        switch chainID {
        case ChainID.solana:
            "Solana"
        case ChainID.ethereum where assetKey != AssetKey.eth:
            "ERC-20"
        default:
            nil
        }
    }
    
    public init(
        walletID: String, assetID: String, chainID: String, assetKey: String,
        kernelAssetID: String, symbol: String, name: String, precision: Int16,
        iconURL: String, amount: String, usdPrice: String, usdChange: String
    ) {
        self.walletID = walletID
        self.assetID = assetID
        self.chainID = chainID
        self.assetKey = assetKey
        self.kernelAssetID = kernelAssetID
        self.symbol = symbol
        self.name = name
        self.precision = precision
        self.iconURL = iconURL
        self.amount = amount
        self.usdPrice = usdPrice
        self.usdChange = usdChange
    }
    
    public func nativeAmount(decimalAmount: Decimal) -> NSDecimalNumber? {
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let nativeAmount = decimalAmountNumber.multiplying(byPowerOf10: precision)
        let isNativeAmountIntegral = nativeAmount == nativeAmount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart)
        return isNativeAmountIntegral ? nativeAmount : nil
    }
    
}

extension Web3Token: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord {
    
    public static let databaseTableName = "tokens"
    
}
