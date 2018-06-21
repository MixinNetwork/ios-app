import Foundation
import WCDBSwift

struct AssetItem: TableCodable, NumberStringLocalizable {

    let assetId: String
    let type: String
    let symbol: String
    let name: String
    let iconUrl: String
    let balance: String
    let publicKey: String
    let priceBtc: String
    let priceUsd: String
    let chainId: String
    let chainIconUrl: String?
    let changeUsd: String
    let confirmations: Int

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
    }
}

extension AssetItem {
    
    var localizedPriceUsd: String {
        return localizedNumberString(priceUsd)
    }
    
    var localizedBalance: String {
        return localizedNumberString(balance.formatBalance())
    }

    func getUSDBalance() -> String {
        return String(format: "≈ %@ USD", (balance.toDouble() * priceUsd.toDouble()).toFormatLegalTender())
    }

    func getUsdChange() -> String {
        return (changeUsd.toDouble() * 100).toFormatLegalTender()
    }
}

extension AssetItem {

    static func createAsset(asset: Asset, chainIconUrl: String?) -> AssetItem {
        return AssetItem(assetId: asset.assetId, type: asset.type, symbol: asset.symbol, name: asset.name, iconUrl: asset.iconUrl, balance: asset.balance, publicKey: asset.publicKey, priceBtc: asset.priceBtc, priceUsd: asset.priceUsd, chainId: asset.chainId, chainIconUrl: chainIconUrl, changeUsd: asset.changeUsd, confirmations: asset.confirmations)
    }

}

