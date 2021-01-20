import Foundation
import GRDB

public final class AssetItem: Asset, NumberStringLocalizable {
    
    public let chain: ChainInfo?
    
    public lazy var localizedBalance = localizedNumberString(balance)
    
    public lazy var localizedFiatMoneyPrice: String = {
        let value = priceUsd.doubleValue * Currency.current.rate
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoneyPrice, sign: .never) ?? ""
    }()
    
    public lazy var localizedFiatMoneyBalance: String = {
        let fiatMoneyBalance = balance.doubleValue * priceUsd.doubleValue * Currency.current.rate
        if let value = CurrencyFormatter.localizedString(from: fiatMoneyBalance, format: .fiatMoney, sign: .never) {
            return "≈ " + Currency.current.symbol + value
        } else {
            return ""
        }
    }()
    
    public lazy var localizedUsdChange: String = {
        let usdChange = changeUsd.doubleValue * 100
        return CurrencyFormatter.localizedString(from: usdChange, format: .fiatMoney, sign: .whenNegative) ?? "0\(currentDecimalSeparator)00"
    }()
    
    public init(asset: Asset, chain: ChainInfo?) {
        self.chain = chain
        super.init(assetId: asset.assetId,
                   type: asset.type,
                   symbol: asset.symbol,
                   name: asset.name,
                   iconUrl: asset.iconUrl,
                   balance: asset.balance,
                   destination: asset.destination,
                   tag: asset.tag,
                   priceBtc: asset.priceBtc,
                   priceUsd: asset.priceUsd,
                   changeUsd: asset.changeUsd,
                   chainId: asset.chainId,
                   confirmations: asset.confirmations,
                   assetKey: asset.assetKey,
                   reserve: asset.reserve)
    }
    
    required init(from decoder: Decoder) throws {
        // GRDB does not support singleValueContainer
        // Decode it in nasty way
        if let container = try? decoder.container(keyedBy: ChainInfo.CodingKeys.self),
           let iconUrl = try? container.decodeIfPresent(String.self, forKey: .iconUrl),
           let name = try? container.decodeIfPresent(String.self, forKey: .name),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .symbol) {
            self.chain = ChainInfo(iconUrl: iconUrl, name: name, symbol: symbol)
        } else {
            self.chain = nil
        }
        try super.init(from: decoder)
    }
    
}

extension AssetItem {
    
    public struct ChainInfo: Codable {
        
        public enum CodingKeys: String, CodingKey {
            case iconUrl = "chain_icon_url"
            case name = "chain_name"
            case symbol = "chain_symbol"
        }
        
        public let iconUrl: String
        public let name: String
        public let symbol: String
        
        public init(iconUrl: String, name: String, symbol: String) {
            self.iconUrl = iconUrl
            self.name = name
            self.symbol = symbol
        }
        
    }
    
}

extension AssetItem {
    
    public static let xin: AssetItem = {
        let asset = Asset(assetId: "c94ac88f-4671-3976-b60a-09064f1811e8",
                          type: "asset",
                          symbol: "XIN",
                          name: "Mixin",
                          iconUrl: "https://images.mixin.one/UasWtBZO0TZyLTLCFQjvE_UYekjC7eHCuT_9_52ZpzmCC-X-NPioVegng7Hfx0XmIUavZgz5UL-HIgPCBECc-Ws=s128",
                          balance: "0",
                          destination: "",
                          tag: "",
                          priceBtc: "0",
                          priceUsd: "0",
                          changeUsd: "0",
                          chainId: "43d61dcd-e413-450d-80b8-101d5e903357",
                          confirmations: 100,
                          assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33",
                          reserve: "0")
        let info = ChainInfo(iconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128", name: "Ether", symbol: "ETH")
        return AssetItem(asset: asset, chain: info)
    }()
    
}
