import Foundation

public class Web3Token: Codable {
    
    public enum AssetKey {
        public static let sol = "11111111111111111111111111111111"
        public static let wrappedSOL = "So11111111111111111111111111111111111111112"
    }
    
    public enum ChainID {
        public static let solana = "solana"
    }
    
    enum CodingKeys: String, CodingKey {
        case fungibleID = "fungible_id"
        case name = "name"
        case symbol = "symbol"
        case iconURL = "icon_url"
        case chainID = "chain_id"
        case chainIconURL = "chain_icon_url"
        case balance = "balance"
        case price = "price"
        case absoluteChange = "change_absolute"
        case percentChange = "change_percent"
        case assetKey = "asset_key"
        case decimalValuePower = "decimals"
    }
    
    public let fungibleID: String
    public let name: String
    public let symbol: String
    public let iconURL: String
    public let chainID: String
    public let chainIconURL: String
    public let balance: String
    public let price: String
    public let absoluteChange: String
    public let percentChange: String
    public let assetKey: String
    public let decimalValuePower: Int16
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: price, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalPercentChange = Decimal(string: percentChange, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalAbsoluteChange = Decimal(string: absoluteChange, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var localizedBalanceWithSymbol = {
        CurrencyFormatter.localizedString(from: decimalBalance,
                                          format: .precision,
                                          sign: .never,
                                          symbol: .custom(symbol))
    }()
    
    public private(set) lazy var localizedPercentChange: String = {
        let string = CurrencyFormatter.localizedString(from: decimalPercentChange, 
                                                       format: .fiatMoney,
                                                       sign: .whenNegative)
        let change = string ?? "0\(currentDecimalSeparator)00"
        return change + "%"
    }()
    
    public private(set) lazy var localizedFiatMoneyPrice: String = {
        let value = decimalUSDPrice * Currency.current.decimalRate
        return CurrencyFormatter.localizedString(from: value,
                                                 format: .fiatMoneyPrice,
                                                 sign: .never,
                                                 symbol: .currencySymbol)
    }()
    
    public private(set) lazy var localizedFiatMoneyBalance: String = {
        let fiatMoneyBalance = decimalBalance * decimalUSDPrice * Currency.current.decimalRate
        return CurrencyFormatter.localizedString(from: fiatMoneyBalance, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
    }()
    
    public func nativeAmount(decimalAmount: Decimal) -> NSDecimalNumber? {
        let decimalAmountNumber = decimalAmount as NSDecimalNumber
        let nativeAmount = decimalAmountNumber.multiplying(byPowerOf10: decimalValuePower)
        let isNativeAmountIntegral = nativeAmount == nativeAmount.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart)
        return isNativeAmountIntegral ? nativeAmount : nil
    }
    
}
