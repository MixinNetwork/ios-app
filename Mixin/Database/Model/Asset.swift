import Foundation
import WCDBSwift

struct Asset: BaseCodable {

    static var tableName: String = "assets"
    static let topAssetsTableName = "top_assets"
    
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
    let changeUsd: String
    let chainId: String
    let confirmations: Int
    let assetKey: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Asset
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
        case confirmations
        case assetKey = "asset_key"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                assetId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}

extension Asset {

    static func createAsset(asset: AssetItem) -> Asset {
        return Asset(assetId: asset.assetId, type: asset.type, symbol: asset.symbol, name: asset.name, iconUrl: asset.iconUrl, balance: asset.balance, destination: asset.destination, tag: asset.tag, priceBtc: asset.priceBtc, priceUsd: asset.priceUsd, changeUsd: asset.changeUsd, chainId: asset.chainId, confirmations: asset.confirmations, assetKey: asset.assetKey)
    }

}
