import Foundation

struct RawToken {
    
    // In the Token structure returned by the API, there are two sets of
    // representations: symbol and name represent the names in the contract,
    // while display_symbol and display_name are used for display purposes.
    // Currently, the client only uses the display_xxx set, so this Model
    // is used for conversion.
    
    let assetID: String
    let kernelAssetID: String
    let displaySymbol: String
    let displayName: String
    let iconURL: String
    let btcPrice: String
    let usdPrice: String
    let chainID: String
    let usdChange: String
    let btcChange: String
    let dust: String
    let confirmations: Int
    let assetKey: String
    let collectionHash: String?
    
    var asToken: Token {
        Token(
            assetID: assetID,
            kernelAssetID: kernelAssetID,
            symbol: displaySymbol,
            name: displayName,
            iconURL: iconURL,
            btcPrice: btcPrice,
            usdPrice: usdPrice,
            chainID: chainID,
            usdChange: usdChange,
            btcChange: btcChange,
            dust: dust,
            confirmations: confirmations,
            assetKey: assetKey,
            collectionHash: collectionHash
        )
    }
    
}

extension RawToken: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case kernelAssetID = "kernel_asset_id"
        case displaySymbol = "display_symbol"
        case displayName = "display_name"
        case iconURL = "icon_url"
        case btcPrice = "price_btc"
        case usdPrice = "price_usd"
        case chainID = "chain_id"
        case usdChange = "change_usd"
        case btcChange = "change_btc"
        case dust
        case confirmations
        case assetKey = "asset_key"
        case collectionHash = "collection_hash"
    }
    
}
