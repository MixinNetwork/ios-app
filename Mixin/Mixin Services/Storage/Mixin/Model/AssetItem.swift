import Foundation
import WCDBSwift

public class AssetItem: TableCodable, NumberStringLocalizable {
    
    let assetId: String
    let type: String
    let symbol: String
    let name: String
    let iconUrl: String
    let balance: String
    let destination: String
    let tag: String
    let priceBtc: String
    let priceUsd: String
    let chainId: String
    let chainIconUrl: String?
    let changeUsd: String
    let confirmations: Int
    var accountName: String?
    var accountTag: String?
    let assetKey: String
    let chainName: String?
    
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
        
    }
    
    lazy var localizedBalance = localizedNumberString(balance)
    
    lazy var localizedFiatMoneyPrice: String = {
        let value = priceUsd.doubleValue * Currency.current.rate
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoneyPrice, sign: .never) ?? ""
    }()
    
    lazy var localizedFiatMoneyBalance: String = {
        let fiatMoneyBalance = balance.doubleValue * priceUsd.doubleValue * Currency.current.rate
        if let value = CurrencyFormatter.localizedString(from: fiatMoneyBalance, format: .fiatMoney, sign: .never) {
            return "≈ " + Currency.current.symbol + value
        } else {
            return ""
        }
    }()
    
    lazy var localizedUsdChange: String = {
        let usdChange = changeUsd.doubleValue * 100
        return CurrencyFormatter.localizedString(from: usdChange, format: .fiatMoney, sign: .whenNegative) ?? "0\(currentDecimalSeparator)00"
    }()
    
    init(assetId: String, type: String, symbol: String, name: String, iconUrl: String, balance: String, destination: String, tag: String, priceBtc: String, priceUsd: String, chainId: String, chainIconUrl: String?, changeUsd: String, confirmations: Int, assetKey: String, chainName: String?) {
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
    }
    
}

extension AssetItem {
    
    static func createAsset(asset: Asset, chainIconUrl: String?, chainName: String?) -> AssetItem {
        return AssetItem(assetId: asset.assetId, type: asset.type, symbol: asset.symbol, name: asset.name, iconUrl: asset.iconUrl, balance: asset.balance, destination: asset.destination, tag: asset.tag, priceBtc: asset.priceBtc, priceUsd: asset.priceUsd, chainId: asset.chainId, chainIconUrl: chainIconUrl, changeUsd: asset.changeUsd, confirmations: asset.confirmations, assetKey: asset.assetKey, chainName: chainName)
    }
    
    static func createDefaultAsset() -> AssetItem  {
        return AssetItem(assetId: "c94ac88f-4671-3976-b60a-09064f1811e8", type: "", symbol: "XIN", name: "Mixin", iconUrl: "https://images.mixin.one/UasWtBZO0TZyLTLCFQjvE_UYekjC7eHCuT_9_52ZpzmCC-X-NPioVegng7Hfx0XmIUavZgz5UL-HIgPCBECc-Ws=s128", balance: "0", destination: "", tag: "", priceBtc: "0", priceUsd: "0", chainId: "43d61dcd-e413-450d-80b8-101d5e903357", chainIconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128", changeUsd: "0", confirmations: 100, assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33", chainName: "Ether")
    }
    
}

extension AssetItem {
    
    var isUseTag: Bool {
        // XRP 23dfb5a5-5d7b-48b6-905f-3970e3176e27
        return assetId == "23dfb5a5-5d7b-48b6-905f-3970e3176e27"
    }
    
}
