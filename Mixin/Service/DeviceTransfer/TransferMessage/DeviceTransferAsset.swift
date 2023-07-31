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
    let depositEntries: [Asset.DepositEntry]?
    let withdrawalMemoPossibility: String?
    
    init(asset: Asset) {
        assetId = asset.assetId
        symbol = asset.symbol
        name = asset.name
        iconUrl = asset.iconUrl
        balance = asset.balance
        destination = asset.destination
        tag = asset.tag
        priceBtc = asset.priceBtc
        priceUsd = asset.priceUsd
        changeUsd = asset.changeUsd
        changeBtc = "0"
        chainId = asset.chainId
        confirmations = asset.confirmations
        assetKey = asset.assetKey
        reserve = asset.reserve
        depositEntries = asset.depositEntries
        withdrawalMemoPossibility = asset.withdrawalMemoPossibility
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
              depositEntries: depositEntries ?? [],
              withdrawalMemoPossibility: withdrawalMemoPossibility)
    }
    
}

extension DeviceTransferAsset: DeviceTransferRecord {
    
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
        case depositEntries = "deposit_entries"
        case withdrawalMemoPossibility = "withdrawal_memo_possibility"
    }
    
}
