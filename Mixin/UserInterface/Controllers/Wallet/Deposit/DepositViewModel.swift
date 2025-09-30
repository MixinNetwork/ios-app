import Foundation
import OrderedCollections
import MixinServices

struct DepositViewModel {
    
    let switchableTokens: [SwitchableToken]
    let selectedTokenIndex: Int?
    let token: any (OnChainToken & ValuableToken)
    let entry: Entry
    let infos: [Info]
    let limitation: DepositAmountLimitation?
    
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
            return ([], nil)
        }()
        let limitation = DepositAmountLimitation(minimum: entry.minimum, maximum: entry.maximum)
        
        self.switchableTokens = switchableTokens
        self.selectedTokenIndex = selectedTokenIndex
        self.token = token
        self.entry = {
            if let tag = entry.tag, !tag.isEmpty {
                return if token.usesTag {
                    .tagging(
                        destination: Entry.Content(
                            title: R.string.localizable.address(),
                            textValue: entry.destination,
                            qrCodeValue: entry.destination,
                            warning: R.string.localizable.deposit_tag_address_notice(token.symbol)
                        ),
                        tag: Entry.Content(
                            title: R.string.localizable.tag(),
                            textValue: tag,
                            qrCodeValue: tag,
                            warning: R.string.localizable.deposit_tag_notice()
                        ),
                        supporting: token.chain?.depositSupporting
                    )
                } else {
                    .tagging(
                        destination: Entry.Content(
                            title: R.string.localizable.address(),
                            textValue: entry.destination,
                            qrCodeValue: entry.destination,
                            warning: R.string.localizable.deposit_memo_address_notice(token.symbol)
                        ),
                        tag: Entry.Content(
                            title: R.string.localizable.withdrawal_memo(),
                            textValue: tag,
                            qrCodeValue: tag,
                            warning: R.string.localizable.deposit_memo_notice()
                        ),
                        supporting: token.chain?.depositSupporting
                    )
                }
            } else {
                let destination = switch token.chainID {
                case ChainID.lightning:
                    Entry.Content(
                        title: R.string.localizable.invoice(),
                        textValue: entry.destination,
                        qrCodeValue: entry.destination.uppercased() // Uppercase for smaller QR-Code image
                    )
                default:
                    Entry.Content(
                        title: R.string.localizable.address(),
                        textValue: entry.destination,
                        qrCodeValue: entry.destination
                    )
                }
                var actions: [Entry.Action] = [.copy, .share]
                if DepositLink.availableForSettingAmount(address: entry.destination, token: token) {
                    actions.insert(.setAmount, at: 1)
                }
                return .general(
                    content: destination,
                    supporting: token.chain?.depositSupporting,
                    actions: actions
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
            if token.chainID == ChainID.lightning,
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
            if let minimum = limitation.minimumDescription(symbol: token.symbol) {
                infos.append(
                    Info(
                        title: R.string.localizable.minimum_deposit(),
                        description: minimum,
                        actions: []
                    )
                )
            }
            if let maximum = limitation.maximumDescription(symbol: token.symbol) {
                infos.append(
                    Info(
                        title: R.string.localizable.maximum_deposit(),
                        description: maximum,
                        actions: []
                    )
                )
            }
            infos.append(
                Info(
                    title: R.string.localizable.block_confirmations(),
                    description: "\(token.confirmations)",
                    presentableInfo: .confirmations(token.confirmations),
                    actions: [.presentInfo]
                )
            )
            return infos
        }()
        
        self.limitation = limitation
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
            return ([], nil)
        }()
        var actions: [Entry.Action] = [.copy, .share]
        if DepositLink.availableForSettingAmount(address: address, token: token) {
            actions.insert(.setAmount, at: 1)
        }
        self.switchableTokens = switchableTokens
        self.selectedTokenIndex = selectedTokenIndex
        self.token = token
        self.entry = .general(
            content: Entry.Content(
                title: R.string.localizable.address(),
                textValue: address,
                qrCodeValue: address,
            ),
            supporting: token.chain?.depositSupporting,
            actions: actions
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
        self.limitation = nil
    }
    
    func link() -> DepositLink? {
        switch entry {
        case let .general(content, _, _):
                .native(address: content.textValue, token: token, limitation: limitation)
        case .tagging:
            nil
        }
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
            let textValue: String
            let qrCodeValue: String
            let warning: String?
            
            init(
                title: String,
                textValue: String,
                qrCodeValue: String?,
                warning: String? = nil
            ) {
                self.title = title.uppercased()
                self.textValue = textValue
                self.qrCodeValue = qrCodeValue ?? textValue
                self.warning = warning
            }
            
        }
        
        enum Action {
            case copy
            case setAmount
            case share
        }
        
        case general(content: Content, supporting: String?, actions: [Action])
        case tagging(destination: Content, tag: Content, supporting: String?)
        
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
                    chainName: "Ethereum",
                    assetID: AssetID.erc20USDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.tron,
                    chainName: "TRON",
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
                    chainName: "BSC",
                    assetID: AssetID.bep20USDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.solana,
                    chainName: "Solana",
                    assetID: AssetID.solanaUSDT,
                    symbol: "USDT"
                ),
                SwitchableToken(
                    chainID: ChainID.ton,
                    chainName: "TON",
                    assetID: AssetID.tonUSDT,
                    symbol: "USD₮"
                ),
            ],
            [
                SwitchableToken(
                    chainID: ChainID.ethereum,
                    chainName: "Ethereum",
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
                    chainName: "BSC",
                    assetID: AssetID.bep20USDC,
                    symbol: "USDC"
                ),
                SwitchableToken(
                    chainID: ChainID.base,
                    chainName: "Base",
                    assetID: AssetID.baseUSDC,
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
    
}
