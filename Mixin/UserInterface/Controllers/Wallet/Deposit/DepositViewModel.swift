import Foundation
import OrderedCollections
import MixinServices

struct DepositViewModel {
    
    let switchableTokens: SwitchableTokens
    let selectedTokenIndex: Int?
    let token: any (OnChainToken & ValuableToken)
    let tokenPrecision: Int
    let entry: Entry
    let infos: [Info]
    let minimumDeposit: String?
    
    init(token: MixinTokenItem, entry: DepositEntry) {
        self.init(token: token, destination: entry.destination, tag: entry.tag)
    }
    
    init<Token: OnChainToken & ValuableToken>(token: Token, destination: String, tag: String?) {
        let (switchableTokens, selectedTokenIndex): (SwitchableTokens, Int?) = {
            for networks in Self.switchableTokens {
                if let index = networks.index(forKey: token.assetID) {
                    return (networks, index)
                }
            }
            return ([token.assetID: token.name], 0)
        }()
        self.switchableTokens = switchableTokens
        self.selectedTokenIndex = selectedTokenIndex
        self.token = token
        
        self.entry = {
            let destination = Entry.Content(
                title: R.string.localizable.address(),
                content: destination,
            )
            let supporting = switch token.chainID {
            case ChainID.bitcoin:
                R.string.localizable.deposit_tip_btc()
            case ChainID.eos:
                R.string.localizable.deposit_tip_eos()
            case ChainID.ethereum:
                R.string.localizable.deposit_tip_eth()
            case ChainID.tron:
                R.string.localizable.deposit_tip_trx()
            default:
                R.string.localizable.deposit_tip_common(token.symbol)
            }
            if let tag, !tag.isEmpty {
                let tagTitle = if token.usesTag {
                    R.string.localizable.tag()
                } else {
                    R.string.localizable.withdrawal_memo()
                }
                return .tagging(
                    destination: destination,
                    tag: Entry.Content(title: tagTitle, content: tag),
                    supporting: supporting
                )
            } else {
                return .general(
                    content: destination,
                    supporting: supporting,
                    actions: [.copy, .setAmount, .share]
                )
            }
        }()
        
        var infos = [
            Info(
                title: R.string.localizable.asset(),
                description: "\(token.name)(\(token.symbol))",
                actions: []
            ),
            Info(
                title: R.string.localizable.network(),
                description: token.depositNetworkName ?? "",
                actions: []
            ),
        ]
        switch token {
        case let token as MixinTokenItem:
            if token.assetID == AssetID.lightningBTC,
               let identityNumber = LoginManager.shared.account?.identityNumber
            {
                let address = identityNumber + "@mixin.id"
                infos.append(
                    Info(
                        title: R.string.localizable.lightning_address(),
                        description: address,
                        presentableInfo: .lightningAddress(address),
                        actions: [.presentInfo]
                    )
                )
            }
            let minimumDeposit = CurrencyFormatter.localizedString(
                from: token.decimalDust,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol)
            )
            infos.append(contentsOf: [
                Info(
                    title: R.string.localizable.minimum_deposit(),
                    description: minimumDeposit,
                    actions: []
                ),
                Info(
                    title: R.string.localizable.block_confirmations(),
                    description: "\(token.confirmations)",
                    presentableInfo: .confirmations(token.confirmations),
                    actions: [.presentInfo]
                ),
            ])
            self.tokenPrecision = MixinToken.precision
            self.minimumDeposit = minimumDeposit
        case let token as Web3TokenItem:
            self.tokenPrecision = Int(token.precision)
            self.minimumDeposit = nil
        default:
            self.tokenPrecision = 0
            self.minimumDeposit = nil
        }
        self.infos = infos
    }
    
    func depositLink(decimalAmount: Decimal) -> String? {
        nil
    }
    
}

extension DepositViewModel {
    
    enum Entry {
        
        struct Content {
            
            let title: String
            let content: String
            
            init(title: String, content: String) {
                self.title = title.uppercased()
                self.content = content
            }
            
        }
        
        enum Action {
            case copy
            case setAmount
            case share
        }
        
        case general(content: Content, supporting: String, actions: [Action])
        case tagging(destination: Content, tag: Content, supporting: String)
        
    }
    
    struct Info {
        
        enum PresentableInfo {
            case confirmations(Int)
            case lightningAddress(String)
        }
        
        enum Action: Hashable {
            case presentInfo
            case copyDescription
        }
        
        let title: String
        let description: String
        let presentableInfo: PresentableInfo?
        let actions: Set<Action>
        
        init(
            title: String,
            description: String,
            presentableInfo: PresentableInfo? = nil,
            actions: Set<Action>
        ) {
            self.title = title.uppercased()
            self.description = description
            self.presentableInfo = presentableInfo
            self.actions = actions
        }
        
    }
    
    // Key is asset id, value is name
    typealias SwitchableTokens = OrderedDictionary<String, String>
    
    private static var switchableTokens: [SwitchableTokens] {
        [
            [
                AssetID.btc:            "Bitcoin",
                AssetID.lightningBTC:   "Lightning",
            ],
            [
                AssetID.erc20USDT:      "ERC-20",
                AssetID.tronUSDT:       "TRON(TRC-20)",
                AssetID.polygonUSDT:    "Polygon",
                AssetID.bep20USDT:      "BEP-20",
                AssetID.solanaUSDT:     "Solana",
            ],
            [
                AssetID.erc20USDC:      "ERC-20",
                AssetID.solanaUSDC:     "Solana",
                AssetID.baseUSDC:       "Base",
                AssetID.polygonUSDC:    "Polygon",
                AssetID.bep20USDC:      "BEP-20",
            ],
            [
                AssetID.eth:            "Ethereum",
                AssetID.baseETH:        "Base",
                AssetID.opMainnetETH:   "Optimism",
                AssetID.arbitrumOneETH: "Arbitrum",
            ],
            [
                AssetID.btc:            "Bitcoin",
                AssetID.lightningBTC:   "Lightning"
            ],
        ]
    }
    
}
