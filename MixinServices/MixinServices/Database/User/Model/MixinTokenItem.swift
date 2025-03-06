import Foundation
import GRDB

public final class MixinTokenItem: MixinToken, ChangeReportingToken, DepositNetworkReportingToken, HideableToken {
    
    public let balance: String
    public let isHidden: Bool
    public let chain: Chain?
    
    public var memoPossibility: WithdrawalMemoPossibility {
        WithdrawalMemoPossibility(rawValue: chain?.withdrawalMemoPossibility) ?? .possible
    }
    
    public private(set) lazy var decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
    public private(set) lazy var decimalUSDBalance = decimalBalance * decimalUSDPrice
    
    public private(set) lazy var localizedBalanceWithSymbol = CurrencyFormatter.localizedString(
        from: decimalBalance,
        format: .precision,
        sign: .never,
        symbol: .custom(symbol)
    )
    
    public private(set) lazy var localizedFiatMoneyPrice = localizeFiatMoneyPrice()
    
    public private(set) lazy var localizedFiatMoneyBalance = "≈ " + CurrencyFormatter.localizedString(
        from: decimalBalance * decimalUSDPrice * Currency.current.decimalRate,
        format: .fiatMoney,
        sign: .never,
        symbol: .currencySymbol
    )
    
    public private(set) lazy var localizedUSDChange = localizeUSDChange()
    public private(set) lazy var localizedUSDPrice = CurrencyFormatter.localizedString(
        from: decimalUSDPrice,
        format: .fiatMoneyPrice,
        sign: .never
    )
    
    public init(token: MixinToken, balance: String, isHidden: Bool, chain: Chain?) {
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
        
        enum JoinedCodingKeys: String, CodingKey {
            case balance
            case hidden
        }
        
        let container = try decoder.container(keyedBy: JoinedCodingKeys.self)
        self.balance = try container.decode(String.self, forKey: .balance)
        self.isHidden = try container.decode(Bool.self, forKey: .hidden)
        self.chain = try? Chain(joinedDecoder: decoder)
        try super.init(from: decoder)
    }
    
}

extension MixinTokenItem {
    
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
        default:
            nil
        }
    }
    
}
