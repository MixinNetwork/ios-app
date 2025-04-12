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
        return CurrencyFormatter.localizedString(from: usdChange, format: .fiatMoney, sign: .whenNegative) ?? zeroWith2Fractions
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
                   depositEntries: asset.depositEntries,
                   withdrawalMemoPossibility: asset.withdrawalMemoPossibility)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        enum JoinQueryCodingKeys: String, CodingKey {
            case chainId
            case name = "chainName"
            case symbol = "chainSymbol"
            case iconUrl = "chainIconUrl"
            case threshold = "chainThreshold"
        }
        
        if let container = try? decoder.container(keyedBy: JoinQueryCodingKeys.self),
           let iconUrl = try? container.decodeIfPresent(String.self, forKey: .iconUrl),
           let name = try? container.decodeIfPresent(String.self, forKey: .name),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .symbol),
           let chainId = try? container.decodeIfPresent(String.self, forKey: .chainId),
           let threshold = try? container.decodeIfPresent(Int.self, forKey: .threshold) {
            self.chain = Chain(chainId: chainId,
                               name: name,
                               symbol: symbol,
                               iconUrl: iconUrl,
                               threshold: threshold,
                               withdrawalMemoPossibility: self.withdrawalMemoPossibility ?? "")
        } else {
            self.chain = nil
        }
    }
    
}

extension AssetItem {
    
    public static let xin: AssetItem = {
        let asset = Asset(assetId: AssetID.xin,
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
                          chainId: ChainID.ethereum,
                          confirmations: 100,
                          assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33",
                          reserve: "0",
                          depositEntries: [],
                          withdrawalMemoPossibility: WithdrawalMemoPossibility.negative.rawValue)
        let chain = Chain(chainId: asset.chainId,
                          name: "Ether",
                          symbol: "ETH",
                          iconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128",
                          threshold: 0,
                          withdrawalMemoPossibility: WithdrawalMemoPossibility.negative.rawValue)
        return AssetItem(asset: asset, chain: chain)
    }()
    
}

extension AssetItem {
    
    public var depositNetworkName: String? {
        switch chainId {
        case ChainID.ethereum:
            return "Ethereum (ERC-20)"
        case ChainID.avalancheXChain:
            return "Avalanche X-Chain"
        case ChainID.bnbBeaconChain:
            return "BNB Beacon Chain (BEP-2)"
        case ChainID.bnbSmartChain:
            return "BNB Smart Chain (BEP-20)"
        case ChainID.tron:
            return assetKey.isDigitsOnly ? "Tron (TRC-10)" : "Tron (TRC-20)"
        case ChainID.bitShares:
            return "BitShares"
        default:
            return chain?.name
        }
    }
    
    public var chainTag: String? {
        if chainId == ChainID.bnbBeaconChain {
            return "BEP-2"
        } else if chainId == ChainID.bnbSmartChain {
            return "BEP-20"
        } else if chainId == ChainID.mvm {
            return "MVM"
        } else if assetId == chainId {
            return nil
        } else {
            switch chainId {
            case ChainID.ethereum:
                return "ERC-20"
            case ChainID.tron:
                return assetKey.isDigitsOnly ? "TRC-10" : "TRC-20"
            case ChainID.eos:
                return "EOS"
            case ChainID.polygon:
                return "Polygon"
            case ChainID.lightning:
                return "Lightning"
            default:
                return nil
            }
        }
    }
    
}
