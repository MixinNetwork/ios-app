import Foundation
import MixinServices

struct DeviceTransferAsset {
    
    let assetId: String
    let symbol: String
    let name: String
    let iconUrl: String
    let balance: String
    let destination: String
    let tag: String?
    let priceBtc: String
    let priceUsd: String
    let changeUsd: String
    let changeBtc: String
    let chainId: String
    let confirmations: Int
    let assetKey: String?
    let reserve: String?
    
    init(asset: Asset) {
        self.assetId = asset.assetId
        self.symbol = asset.symbol
        self.name = asset.name
        self.iconUrl = asset.iconUrl
        self.balance = asset.balance
        self.destination = asset.destination
        self.tag = asset.tag
        self.priceBtc = asset.priceBtc
        self.priceUsd = asset.priceUsd
        self.changeUsd = asset.changeUsd
        self.changeBtc = "0"
        self.chainId = asset.chainId
        self.confirmations = asset.confirmations
        self.assetKey = asset.assetKey
        self.reserve = asset.reserve
    }
    
    func toAsset() -> Asset {
        Asset(assetId: assetId,
              type: "asset",
              symbol: symbol,
              name: name,
              iconUrl: iconUrl,
              balance: balance,
              destination: destination,
              tag: tag ?? "",
              priceBtc: priceBtc,
              priceUsd: priceUsd,
              changeUsd: changeUsd,
              chainId: chainId,
              confirmations: confirmations,
              assetKey: assetKey ?? "",
              reserve: reserve ?? "",
              depositEntries: [])
    }
    
}

extension DeviceTransferAsset: Codable {
    
    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case symbol
        case name
        case iconUrl = "icon_url"
        case balance
        case destination
        case tag
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case changeUsd = "change_usd"
        case changeBtc = "change_btc"
        case chainId = "chain_id"
        case confirmations
        case assetKey = "asset_key"
        case reserve
    }
    
}
