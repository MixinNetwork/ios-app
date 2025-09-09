import Foundation
import MixinServices

struct DeviceTransferToken {
    
    let assetID: String
    let kernelAssetID: String
    let symbol: String
    let name: String
    let iconURL: String
    let btcPrice: String
    let usdPrice: String
    let chainID: String
    let usdChange: String
    let btcChange: String
    let dust: String
    let confirmations: Int
    let assetKey: String
    let precision: Int16?
    let collectionHash: String?
    
    init(token: MixinToken) {
        assetID = token.assetID
        kernelAssetID = token.kernelAssetID
        symbol = token.symbol
        name = token.name
        iconURL = token.iconURL
        btcPrice = token.btcPrice
        usdPrice = token.usdPrice
        chainID = token.chainID
        usdChange = token.usdChange
        btcChange = token.btcChange
        dust = token.dust
        confirmations = token.confirmations
        assetKey = token.assetKey
        precision = token.precision
        collectionHash = token.collectionHash
    }
    
    func toToken() -> MixinToken {
        MixinToken(
            assetID: assetID,
            kernelAssetID: kernelAssetID,
            symbol: symbol,
            name: name,
            iconURL: iconURL,
            btcPrice: btcPrice,
            usdPrice: usdPrice,
            chainID: chainID,
            usdChange: usdChange,
            btcChange: btcChange,
            dust: dust,
            confirmations: confirmations,
            assetKey: assetKey,
            precision: precision ?? MixinToken.invalidPrecision,
            collectionHash: collectionHash
        )
    }
    
}

extension DeviceTransferToken: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case kernelAssetID = "kernel_asset_id"
        case symbol
        case name
        case iconURL = "icon_url"
        case btcPrice = "price_btc"
        case usdPrice = "price_usd"
        case chainID = "chain_id"
        case usdChange = "change_usd"
        case btcChange = "change_btc"
        case dust
        case confirmations
        case assetKey = "asset_key"
        case precision
        case collectionHash = "collection_hash"
    }
    
}
