import Foundation

public class TopAsset: Asset {
    
    public override class var databaseTableName: String {
        "top_assets"
    }
    
    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assetId, forKey: .assetId)
        try container.encode(type, forKey: .type)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(name, forKey: .name)
        try container.encode(iconUrl, forKey: .iconUrl)
        try container.encode(balance, forKey: .balance)
        try container.encode(destination, forKey: .destination)
        try container.encode(tag, forKey: .tag)
        try container.encode(priceBtc, forKey: .priceBtc)
        try container.encode(priceUsd, forKey: .priceUsd)
        try container.encode(changeUsd, forKey: .changeUsd)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(confirmations, forKey: .confirmations)
        try container.encode(assetKey, forKey: .assetKey)
        try container.encode(reserve, forKey: .reserve)
        // Do not encode `depositEntries` because there's no column for it in database
    }
    
}
