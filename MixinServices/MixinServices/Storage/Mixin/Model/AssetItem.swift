import Foundation
import WCDBSwift

public class AssetItem: TableCodable, NumberStringLocalizable {
    
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
    public let chainId: String
    public let chainIconUrl: String?
    public let changeUsd: String
    public let confirmations: Int
    public var accountName: String?
    public var accountTag: String?
    public let assetKey: String
    public let chainName: String?
    public let chainSymbol: String
    public let reserve: String
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = AssetItem
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
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
        case chainIconUrl = "chain_icon_url"
        case confirmations
        case assetKey = "asset_key"
        case chainName = "chain_name"
        case chainSymbol = "chain_symbol"
        case reserve
        
    }
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .us) ?? 0
    public private(set) lazy var decimalBTCPrice = Decimal(string: priceBtc, locale: .us) ?? 0
    public private(set) lazy var decimalUSDPrice = Decimal(string: priceUsd, locale: .us) ?? 0
    public private(set) lazy var decimalUSDChange = Decimal(string: changeUsd, locale: .us) ?? 0
    
    public private(set) lazy var localizedBalance = localizedNumberString(balance)
    
    public private(set) lazy var localizedFiatMoneyPrice: String = {
        let value = decimalUSDPrice * Currency.current.rate
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoneyPrice, sign: .never)
    }()
    
    public private(set) lazy var localizedFiatMoneyBalance = CurrencyFormatter.localizedFiatMoneyAmount(asset: self, assetAmount: decimalBalance)
    
    public private(set) lazy var localizedUsdChange: String = {
        let value = decimalUSDChange * 100
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .whenNegative)
    }()
    
    public init(assetId: String, type: String, symbol: String, name: String, iconUrl: String, balance: String, destination: String, tag: String, priceBtc: String, priceUsd: String, chainId: String, chainIconUrl: String?, changeUsd: String, confirmations: Int, assetKey: String, chainName: String?, chainSymbol: String, reserve: String) {
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
        self.chainId = chainId
        self.chainIconUrl = chainIconUrl
        self.changeUsd = changeUsd
        self.confirmations = confirmations
        self.assetKey = assetKey
        self.chainName = chainName
        self.chainSymbol = chainSymbol
        self.reserve = reserve
    }
    
    public convenience init(asset: Asset, chainIconUrl: String?, chainName: String?, chainSymbol: String) {
        self.init(assetId: asset.assetId,
                  type: asset.type,
                  symbol: asset.symbol,
                  name: asset.name,
                  iconUrl: asset.iconUrl,
                  balance: asset.balance,
                  destination: asset.destination,
                  tag: asset.tag,
                  priceBtc: asset.priceBtc,
                  priceUsd: asset.priceUsd,
                  chainId: asset.chainId,
                  chainIconUrl: chainIconUrl,
                  changeUsd: asset.changeUsd,
                  confirmations: asset.confirmations,
                  assetKey: asset.assetKey,
                  chainName: chainName,
                  chainSymbol: chainSymbol,
                  reserve: asset.reserve)
    }
    
}

extension AssetItem {
    
    public var isUseTag: Bool {
        // XRP 23dfb5a5-5d7b-48b6-905f-3970e3176e27
        return assetId == "23dfb5a5-5d7b-48b6-905f-3970e3176e27"
    }
    
    public var isBitcoinChain: Bool {
        return chainId == "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
    }
    
    public var isEOSChain: Bool {
        return chainId == "6cfe566e-4aad-470b-8c9a-2fd35b49c68d"
    }
    
}

extension AssetItem {
    
    public static let xin = AssetItem(assetId: "c94ac88f-4671-3976-b60a-09064f1811e8",
                                      type: "",
                                      symbol: "XIN",
                                      name: "Mixin",
                                      iconUrl: "https://images.mixin.one/UasWtBZO0TZyLTLCFQjvE_UYekjC7eHCuT_9_52ZpzmCC-X-NPioVegng7Hfx0XmIUavZgz5UL-HIgPCBECc-Ws=s128",
                                      balance: "0",
                                      destination: "",
                                      tag: "",
                                      priceBtc: "0",
                                      priceUsd: "0",
                                      chainId: "43d61dcd-e413-450d-80b8-101d5e903357",
                                      chainIconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128",
                                      changeUsd: "0",
                                      confirmations: 100,
                                      assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33",
                                      chainName: "Ether", chainSymbol: "ETH", reserve: "0")

    public static let bitcoinAssetId = "c6d0c728-2624-429b-8e0d-d9d19b6592fa"
    
}
