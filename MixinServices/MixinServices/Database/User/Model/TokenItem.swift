import Foundation
import GRDB

public final class TokenItem: Token, NumberStringLocalizable {
    
    public let balance: String
    public let isHidden: Bool
    public let chain: Chain?
    
    public var memoPossibility: WithdrawalMemoPossibility {
        WithdrawalMemoPossibility(rawValue: chain?.withdrawalMemoPossibility) ?? .possible
    }
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
    
    public private(set) lazy var localizedBalance = localizedNumberString(balance)
    public private(set) lazy var localizedBalanceWithSymbol = CurrencyFormatter.localizedString(from: decimalBalance,
                                                                                                format: .precision,
                                                                                                sign: .never,
                                                                                                symbol: .custom(symbol))
    
    public lazy var localizedFiatMoneyPrice = CurrencyFormatter.localizedString(
        from: decimalUSDPrice * Currency.current.decimalRate,
        format: .fiatMoneyPrice,
        sign: .never,
        symbol: .currencySymbol
    )
    
    public lazy var localizedFiatMoneyBalance: String = {
        let fiatMoneyBalance = balance.doubleValue * usdPrice.doubleValue * Currency.current.rate
        if let value = CurrencyFormatter.localizedString(from: fiatMoneyBalance, format: .fiatMoney, sign: .never) {
            return "≈ " + Currency.current.symbol + value
        } else {
            return ""
        }
    }()
    
    public lazy var localizedUSDChange = NumberFormatter.percentage.string(decimal: decimalUSDChange)
    public lazy var localizedUSDPrice = CurrencyFormatter.localizedString(
        from: decimalUSDPrice,
        format: .fiatMoneyPrice,
        sign: .never
    )
    
    public init(token: Token, balance: String, isHidden: Bool, chain: Chain?) {
        self.balance = balance
        self.isHidden = isHidden
        self.chain = chain
        super.init(assetID: token.assetID,
                   kernelAssetID: token.kernelAssetID,
                   symbol: token.symbol,
                   name: token.name,
                   iconURL: token.iconURL,
                   btcPrice: token.btcPrice,
                   usdPrice: token.usdPrice,
                   chainID: token.chainID,
                   usdChange: token.usdChange,
                   btcChange: token.btcChange,
                   dust: token.dust,
                   confirmations: token.confirmations,
                   assetKey: token.assetKey,
                   collectionHash: token.collectionHash)
    }
    
    required init(from decoder: Decoder) throws {
        
        enum ChainCodingKeys: String, CodingKey {
            case balance
            case hidden
            case chainID = "chain_id"
            case chainName = "chain_name"
            case chainSymbol = "chain_symbol"
            case chainIconURL = "chain_icon_url"
            case chainThreshold = "chain_threshold"
            case chainWithdrawalMemoPossibility = "chain_withdrawal_memo_possibility"
        }
        
        let container = try decoder.container(keyedBy: ChainCodingKeys.self)
        self.balance = try container.decode(String.self, forKey: .balance)
        self.isHidden = try container.decode(Bool.self, forKey: .hidden)
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
                          iconURL: "https://images.mixin.one/UasWtBZO0TZyLTLCFQjvE_UYekjC7eHCuT_9_52ZpzmCC-X-NPioVegng7Hfx0XmIUavZgz5UL-HIgPCBECc-Ws=s128",
                          btcPrice: "0",
                          usdPrice: "0",
                          chainID: ChainID.ethereum,
                          usdChange: "0",
                          btcChange: "0",
                          dust: "0.0001",
                          confirmations: 100,
                          assetKey: "0xa974c709cfb4566686553a20790685a47aceaa33",
                          collectionHash: nil)
        let chain = Chain(chainId: token.chainID,
                          name: "Ether",
                          symbol: "ETH",
                          iconUrl: "https://images.mixin.one/zVDjOxNTQvVsA8h2B4ZVxuHoCF3DJszufYKWpd9duXUSbSapoZadC7_13cnWBqg0EmwmRcKGbJaUpA8wFfpgZA=s128",
                          threshold: 0,
                          withdrawalMemoPossibility: WithdrawalMemoPossibility.negative.rawValue)
        return TokenItem(token: token, balance: "0", isHidden: false, chain: chain)
    }()
    
}

extension TokenItem {
    
    public var depositNetworkName: String? {
        switch chainID {
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
        switch chainID {
        case ChainID.bnbSmartChain:
            "BEP-20"
        case ChainID.base:
            "Base"
        case assetID:
            nil
        case ChainID.ethereum:
            "ERC-20"
        case ChainID.tron:
            (assetKey ?? "").isDigitsOnly ? "TRC-10" : "TRC-20"
        case ChainID.eos:
            "EOS"
        case ChainID.polygon:
            "Polygon"
        case ChainID.solana:
            "Solana"
        case ChainID.lightning:
            "Lightning"
        default:
            nil
        }
    }
    
}
