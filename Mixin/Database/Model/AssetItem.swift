import Foundation
import WCDBSwift

struct AssetItem: TableCodable, AssetKeyConvertible {

    let assetId: String
    let type: String
    let symbol: String
    let name: String
    let iconUrl: String
    let balance: String
    let publicKey: String?
    let priceBtc: String
    let priceUsd: String
    let chainId: String
    let chainIconUrl: String?
    let changeUsd: String
    let confirmations: Int
    var accountName: String?
    var accountTag: String?

    enum CodingKeys: String, CodingTableKey {
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        typealias Root = AssetItem
        case assetId = "asset_id"
        case type
        case symbol
        case name
        case iconUrl = "icon_url"
        case balance
        case publicKey = "public_key"
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case changeUsd = "change_usd"
        case chainId = "chain_id"
        case chainIconUrl = "chain_icon_url"
        case confirmations
        case accountName = "account_name"
        case accountTag = "account_tag"
    }
}

extension AssetItem {
    
    var localizedPriceUsd: String {
        return decimalSeparatorLocalized(priceUsd)
    }
    
    var localizedBalance: String {
        return CurrencyFormatter.localizedString(from: balance, format: .precision, sign: .never) ?? balance
    }
    
    var localizedUSDBalance: String {
        let usdBalance = balance.doubleValue * priceUsd.doubleValue
        if let value = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
            return "≈ $" + value
        } else {
            return ""
        }
    }
    
    var localizedUSDChange: String {
        let usdChange = changeUsd.doubleValue * 100
        return CurrencyFormatter.localizedString(from: usdChange, format: .legalTender, sign: .whenNegative) ?? ""
    }
    
}

extension AssetItem {

    static func createAsset(asset: Asset, chainIconUrl: String?) -> AssetItem {
        return AssetItem(assetId: asset.assetId, type: asset.type, symbol: asset.symbol, name: asset.name, iconUrl: asset.iconUrl, balance: asset.balance, publicKey: asset.publicKey, priceBtc: asset.priceBtc, priceUsd: asset.priceUsd, chainId: asset.chainId, chainIconUrl: chainIconUrl, changeUsd: asset.changeUsd, confirmations: asset.confirmations, accountName: asset.accountName, accountTag: asset.accountTag)
    }

}
