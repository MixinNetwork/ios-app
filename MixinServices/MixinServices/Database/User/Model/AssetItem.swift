import Foundation
import GRDB

public final class AssetItem: Asset, NumberStringLocalizable {
    
    public var chain: Chain?
    
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
    
    public init(asset: Asset, chain: Chain) {
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
                   reserve: asset.reserve,
                   depositEntries: asset.depositEntries)
    }
    
    required init(from decoder: Decoder) throws {
        // GRDB does not support singleValueContainer
        // Decode it in nasty way
        if let container = try? decoder.container(keyedBy: Chain.JoinQueryCodingKeys.self),
           let iconUrl = try? container.decodeIfPresent(String.self, forKey: .iconUrl),
           let name = try? container.decodeIfPresent(String.self, forKey: .name),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .symbol),
           let chainId = try? container.decodeIfPresent(String.self, forKey: .chainId),
           let threshold = try? container.decodeIfPresent(Int.self, forKey: .threshold) {
            self.chain = Chain(chainId: chainId, name: name, symbol: symbol, iconUrl: iconUrl, threshold: threshold)
        } else {
            self.chain = nil
        }
        try super.init(from: decoder)
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
                          reserve: "0",
                          depositEntries: [])
        let chain = Chain(chainId: asset.chainId,
                          name: "Ether",
                          symbol: "ETH",
                          iconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128",
                          threshold: 0)
        return AssetItem(asset: asset, chain: chain)
    }()
    
}

extension AssetItem {
    
    public var depositNetworkName: String? {
        switch chainId {
        case "43d61dcd-e413-450d-80b8-101d5e903357":
            return "Ethereum (ERC-20)"
        case "cbc77539-0a20-4666-8c8a-4ded62b36f0a":
            return "Avalanche X-Chain"
        case "17f78d7c-ed96-40ff-980c-5dc62fecbc85":
            return "BNB Beacon Chain (BEP-2)"
        case "1949e683-6a08-49e2-b087-d6b72398588f":
            return "BNB Smart Chain (BEP-20)"
        case "25dabac5-056a-48ff-b9f9-f67395dc407c":
            return assetKey.isDigitsOnly ? "Tron (TRC-10)" : "Tron (TRC-20)"
        case "05891083-63d2-4f3d-bfbe-d14d7fb9b25a":
            return "BitShares"
        default:
            return chain?.name
        }
    }
    
    public var chainTag: String? {
        // Show chain tag for BNB on BEP-2/BEP-20
        if chainId == "17f78d7c-ed96-40ff-980c-5dc62fecbc85" {
            return "BEP-2"
        } else if chainId == "1949e683-6a08-49e2-b087-d6b72398588f" {
            return "BEP-20"
        } else if chainId == "a0ffd769-5850-4b48-9651-d2ae44a3e64d" {
            return "MVM"
        } else if assetId == chainId {
            return nil
        } else {
            switch chainId {
            case "43d61dcd-e413-450d-80b8-101d5e903357":
                return "ERC-20"
            case "25dabac5-056a-48ff-b9f9-f67395dc407c":
                return assetKey.isDigitsOnly ? "TRC-10" : "TRC-20"
            case "6cfe566e-4aad-470b-8c9a-2fd35b49c68d":
                return "EOS"
            case "b7938396-3f94-4e0a-9179-d3440718156f":
                return "Polygon"
            default:
                return nil
            }
        }
    }
    
}
