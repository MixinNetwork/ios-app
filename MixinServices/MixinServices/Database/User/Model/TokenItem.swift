import Foundation
import GRDB

public final class TokenItem: Token, NumberStringLocalizable {
    
    public let balance: String
    public let chain: Chain?
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
    
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
    
    public init(token: Token, balance: String, chain: Chain) {
        self.balance = balance
        self.chain = chain
        super.init(assetID: token.assetID,
                   kernelAssetID: token.kernelAssetID,
                   symbol: token.symbol,
                   name: token.name,
                   iconURL: token.iconUrl,
                   btcPrice: token.priceBtc,
                   usdPrice: token.priceUsd,
                   chainID: token.chainId,
                   usdChange: token.changeUsd,
                   btcChange: token.btcChange,
                   confirmations: token.confirmations,
                   assetKey: token.assetKey)
    }
    
    required init(from decoder: Decoder) throws {
        
        enum ChainCodingKeys: String, CodingKey {
            case balance
            case chainID = "chain_id"
            case chainName = "chain_name"
            case chainSymbol = "chain_symbol"
            case chainIconURL = "chain_icon_url"
            case chainThreshold = "chain_threshold"
            case chainWithdrawalMemoPossibility = "chain_withdrawal_memo_possibility"
        }
        
        let container = try decoder.container(keyedBy: ChainCodingKeys.self)
        self.balance = try container.decode(String.self, forKey: .balance)
        if let id = try? container.decodeIfPresent(String.self, forKey: .chainID),
           let name = try? container.decodeIfPresent(String.self, forKey: .chainName),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .chainSymbol),
           let iconURL = try? container.decodeIfPresent(String.self, forKey: .chainIconURL),
           let threshold = try? container.decodeIfPresent(Int.self, forKey: .chainThreshold),
           let withdrawalMemoPossibility = try? container.decodeIfPresent(String.self, forKey: .chainWithdrawalMemoPossibility)
        {
            self.chain = Chain(chainId: id,
                               name: name,
                               symbol: symbol,
                               iconUrl: iconURL,
                               threshold: threshold,
                               withdrawalMemoPossibility: withdrawalMemoPossibility)
        } else {
            self.chain = nil
        }
        try super.init(from: decoder)
    }
    
}

extension TokenItem {
    
    public static let xin: TokenItem = {
        let token = Token(assetID: AssetID.xin,
                          kernelAssetID: "",
                          symbol: "XIN",
                          name: "Mixin",
                          iconURL: URL(string: "https://images.mixin.one/UasWtBZO0TZyLTLCFQjvE_UYekjC7eHCuT_9_52ZpzmCC-X-NPioVegng7Hfx0XmIUavZgz5UL-HIgPCBECc-Ws=s128"),
                          btcPrice: "0",
                          usdPrice: "0",
                          chainID: ChainID.ethereum,
                          usdChange: "0",
                          btcChange: "0",
                          confirmations: 100,
                          assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33")
        let chain = Chain(chainId: token.chainId,
                          name: "Ether",
                          symbol: "ETH",
                          iconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128",
                          threshold: 0,
                          withdrawalMemoPossibility: WithdrawalMemoPossibility.negative.rawValue)
        return TokenItem(token: token, balance: "0", chain: chain)
    }()
    
}

extension TokenItem {
    
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
            return (assetKey ?? "").isDigitsOnly ? "Tron (TRC-10)" : "Tron (TRC-20)"
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
        } else if assetID == chainId {
            return nil
        } else {
            switch chainId {
            case ChainID.ethereum:
                return "ERC-20"
            case ChainID.tron:
                return (assetKey ?? "").isDigitsOnly ? "TRC-10" : "TRC-20"
            case ChainID.eos:
                return "EOS"
            case ChainID.polygon:
                return "Polygon"
            default:
                return nil
            }
        }
    }
    
}
