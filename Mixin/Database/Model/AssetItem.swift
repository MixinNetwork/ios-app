import Foundation
import WCDBSwift

struct AssetItem: TableCodable {

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
        case chainId = "chain_id"
        case chainIconUrl = "chain_icon_url"
    }
}

extension AssetItem {

    func getOriginalBalance() -> String {
        return String(format: "%@ %@", balance.formatBalance(), symbol)
    }

    func getUSDBalance() -> String {
        return String(format: "≈ %@ USD", (balance.toDouble() * priceUsd.toDouble()).toFormatLegalTender())
    }

}

