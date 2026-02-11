import Foundation
import GRDB

public class Web3Token: Codable, Token, ValuableToken, ChangeReportingToken {
    
    public enum AssetKey {
        public static let sol = "11111111111111111111111111111111"
        public static let wrappedSOL = "So11111111111111111111111111111111111111112"
        public static let eth = "0x0000000000000000000000000000000000000000"
    }
    
    public enum CodingKeys: String, CodingKey {
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
        case level
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
    public let level: Int
    
    public private(set) lazy var decimalBalance = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    public private(set) lazy var decimalUSDPrice = Decimal(string: usdPrice, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDChange = (Decimal(string: usdChange, locale: .enUSPOSIX) ?? 0) / 100
    
    public private(set) lazy var localizedUSDChange = localizeUSDChange()
    public private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    public private(set) lazy var localizedBalanceWithSymbol = localizeBalanceWithSymbol()
    public private(set) lazy var localizedFiatMoneyBalance = localizeFiatMoneyBalance()
    public private(set) lazy var estimatedFiatMoneyBalance = estimateFiatMoneyBalance()
    
    public var isPrecisionReady: Bool {
        true
    }
    
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
        iconURL: String, amount: String, usdPrice: String, usdChange: String,
        level: Int,
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
        self.level = level
    }
    
    public init(
        token: Web3Token,
        replacingAmountWith arbitraryAmount: String
    ) {
        self.walletID = token.walletID
        self.assetID = token.assetID
        self.chainID = token.chainID
        self.assetKey = token.assetKey
        self.kernelAssetID = token.kernelAssetID
        self.symbol = token.symbol
        self.name = token.name
        self.precision = token.precision
        self.iconURL = token.iconURL
        self.amount = arbitraryAmount
        self.usdPrice = token.usdPrice
        self.usdChange = token.usdChange
        self.level = token.level
    }
    
    public init(
        token: Web3Token,
        replacingWalletID walletID: String,
        amount: String,
        usdPrice: String,
    ) {
        self.walletID = walletID
        self.assetID = token.assetID
        self.chainID = token.chainID
        self.assetKey = token.assetKey
        self.kernelAssetID = token.kernelAssetID
        self.symbol = token.symbol
        self.name = token.name
        self.precision = token.precision
        self.iconURL = token.iconURL
        self.amount = amount
        self.usdPrice = usdPrice
        self.usdChange = token.usdChange
        self.level = token.level
    }
    
    public func nativeAmount(decimalAmount: Decimal) -> NSDecimalNumber? {
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let nativeAmount = decimalAmountNumber.multiplying(byPowerOf10: precision)
        let isNativeAmountIntegral = nativeAmount == nativeAmount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart)
        return isNativeAmountIntegral ? nativeAmount : nil
    }
    
}

extension Web3Token: TableRecord, PersistableRecord, MixinFetchableRecord, MixinEncodableRecord, DatabaseColumnConvertible {
    
    public static let databaseTableName = "tokens"
    
}

extension Web3Token: MaliciousDistinguishable {
    
    public var isMalicious: Bool {
        level <= Web3Reputation.Level.spam.rawValue
    }
    
}
