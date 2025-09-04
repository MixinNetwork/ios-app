import Foundation
import OrderedCollections
import MixinServices

struct DepositViewModel {
    
    let switchableTokens: [SwitchableToken]
    let selectedTokenIndex: Int?
    let token: any (OnChainToken & ValuableToken)
    let tokenPrecision: Int
    let entry: Entry
    let infos: [Info]
    let minimumDeposit: String?
    
    init(token: MixinTokenItem, entry: DepositEntry) {
        let (switchableTokens, selectedTokenIndex): ([SwitchableToken], Int?) = {
            for tokens in Self.switchableTokens {
                let index = tokens.firstIndex {
                    token.assetID == $0.assetID
                }
                if let index {
                    return (tokens, index)
                }
            }
            return ([SwitchableToken(token: token)], 0)
        }()
        
        let minimumDeposit = CurrencyFormatter.localizedString(
            from: token.decimalDust,
            format: .precision,
            sign: .never,
            symbol: .custom(token.symbol)
        )
        
        self.switchableTokens = switchableTokens
        self.selectedTokenIndex = selectedTokenIndex
        self.token = token
        self.tokenPrecision = MixinToken.precision
        self.entry = {
            let destination = Entry.Content(
                title: R.string.localizable.address(),
                value: entry.destination,
            )
            let supporting = Self.depositSupportedTokens(
                chainID: token.chainID,
                symbol: token.symbol
            )
            if let tag = entry.tag, !tag.isEmpty {
                let tagTitle = if token.usesTag {
                    R.string.localizable.tag()
                } else {
                    R.string.localizable.withdrawal_memo()
                }
                return .tagging(
                    destination: destination,
                    tag: Entry.Content(title: tagTitle, value: tag),
                    supporting: supporting
                )
            } else {
                return .general(
                    content: destination,
                    supporting: supporting,
                    actions: [.copy, .share]
                )
            }
        }()
        self.infos = {
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
            if token.assetID == AssetID.lightningBTC,
               let identityNumber = LoginManager.shared.account?.identityNumber
            {
                let address = identityNumber + "@mixin.id"
                let info = Info(
                    title: R.string.localizable.lightning_address(),
                    description: address,
                    presentableInfo: .lightningAddress(address),
                    actions: [.presentInfo, .copyDescription]
                )
                infos.insert(info, at: 0)
            }
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
            return infos
        }()
        self.minimumDeposit = minimumDeposit
    }
    
    init(token: Web3TokenItem, address: String, switchableChainIDs: Set<String>) {
        let (switchableTokens, selectedTokenIndex): ([SwitchableToken], Int?) = {
            for tokens in Self.switchableTokens {
                let availableTokens = tokens.filter { token in
                    switchableChainIDs.contains(token.chainID)
                }
                let index = availableTokens.firstIndex {
                    token.assetID == $0.assetID
                }
                if let index {
                    return (availableTokens, index)
                }
            }
            return ([SwitchableToken(token: token)], 0)
        }()
        self.switchableTokens = switchableTokens
        self.selectedTokenIndex = selectedTokenIndex
        self.token = token
        self.tokenPrecision = Int(token.precision)
        self.entry = .general(
            content: Entry.Content(
                title: R.string.localizable.address(),
                value: address,
            ),
            supporting: Self.depositSupportedTokens(
                chainID: token.chainID,
                symbol: token.symbol
            ),
            actions: [.copy, .share]
        )
        self.infos = [
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
        self.minimumDeposit = nil
    }
    
    func depositLink(decimalAmount: Decimal) -> String? {
        nil
    }
    
}

extension DepositViewModel {
    
    struct SwitchableToken: Equatable, Hashable {
        
        let chainID: String
        let chainName: String
        let assetID: String
        let symbol: String
        
        init(chainID: String, chainName: String, assetID: String, symbol: String) {
            self.chainID = chainID
            self.chainName = chainName
            self.assetID = assetID
            self.symbol = symbol
        }
        
        init<T: OnChainToken>(token: T) {
            self.chainID = token.chainID
            self.assetID = token.assetID
            self.chainName = token.chain?.name ?? ""
            self.symbol = token.symbol
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.assetID == rhs.assetID
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(assetID)
        }
        
    }
    
    enum Entry {
        
        struct Content {
            
            let title: String
            let value: String
            
            init(title: String, value: String) {
                self.title = title.uppercased()
                self.value = value
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
    
    private static var switchableTokens: [[SwitchableToken]] {
        [
            [
                SwitchableToken(
                    chainID: ChainID.bitcoin,
                    chainName: "Bitcoin",
                    assetID: AssetID.btc,
                    symbol: "BTC"
                ),
                SwitchableToken(
                    chainID: ChainID.lightning,
                    chainName: "Lightning",
                    assetID: AssetID.lightningBTC,
                    symbol: "BTC"
                ),
            ],
            [
                SwitchableToken(
                    chainID: ChainID.ethereum,
                    chainName: "ERC-20",
                    assetID: AssetID.erc20USDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.tron,
                    chainName: "TRON(TRC-20)",
                    assetID: AssetID.tronUSDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.polygon,
                    chainName: "Polygon",
                    assetID: AssetID.polygonUSDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.bnbSmartChain,
                    chainName: "BEP-20",
                    assetID: AssetID.bep20USDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.solana,
                    chainName: "Solana",
                    assetID: AssetID.solanaUSDT,
                    symbol: "USDT"
                ),
            ],
            [
                SwitchableToken(
                    chainID: ChainID.ethereum,
                    chainName: "ERC-20",
                    assetID: AssetID.erc20USDC,
                    symbol: "USDC"
                ),
                SwitchableToken(
                    chainID: ChainID.polygon,
                    chainName: "Polygon",
                    assetID: AssetID.polygonUSDC,
                    symbol: "USDC"
                ),
                SwitchableToken(
                    chainID: ChainID.bnbSmartChain,
                    chainName: "BEP-20",
                    assetID: AssetID.bep20USDC,
                    symbol: "USDC"
                ),
                SwitchableToken(
                    chainID: ChainID.solana,
                    chainName: "Solana",
                    assetID: AssetID.solanaUSDC,
                    symbol: "USDC"
                ),
            ],
            [
                SwitchableToken(
                    chainID: ChainID.ethereum,
                    chainName: "Ethereum",
                    assetID: AssetID.eth,
                    symbol: "ETH"
                ),
                SwitchableToken(
                    chainID: ChainID.base,
                    chainName: "Base",
                    assetID: AssetID.baseETH,
                    symbol: "ETH"
                ),
                SwitchableToken(
                    chainID: ChainID.opMainnet,
                    chainName: "Optimism",
                    assetID: AssetID.opMainnetETH,
                    symbol: "ETH"
                ),
                SwitchableToken(
                    chainID: ChainID.arbitrumOne,
                    chainName: "Arbitrum",
                    assetID: AssetID.arbitrumOneETH,
                    symbol: "ETH"
                ),
            ],
        ]
    }
    
    private static func depositSupportedTokens(chainID: String, symbol: String) -> String {
        switch chainID {
        case ChainID.bitcoin:
            R.string.localizable.deposit_tip_btc()
        case ChainID.eos:
            R.string.localizable.deposit_tip_eos()
        case ChainID.ethereum:
            R.string.localizable.deposit_tip_eth()
        case ChainID.tron:
            R.string.localizable.deposit_tip_trx()
        default:
            R.string.localizable.deposit_tip_common(symbol)
        }
    }
    
}
