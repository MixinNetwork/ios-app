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
    
    init(token: Token) {
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
    }
    
    func toToken() -> Token {
        Token(assetID: assetID,
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
              assetKey: assetKey)
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
    }
    
}
