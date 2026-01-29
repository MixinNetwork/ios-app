import UIKit
import MixinServices

struct DepositLink {
    
    typealias Token = any (OnChainToken & ValuableToken)
    
    enum Chain {
        case mixin(Mixin)
        case native(Native)
    }
    
    let chain: Chain
    let textValue: String
    let qrCodeValue: String // Could be different from `textValue`. For example, in lightning network the `qrCodeValue` is uppercased.
    
    private init(chain: Chain, value: String) {
        self.chain = chain
        self.textValue = value
        self.qrCodeValue = switch chain {
        case .native(let context) where context.token.chainID == ChainID.lightning:
            value.uppercased() // Uppercase for smaller QR-Code image
        default:
            value
        }
    }
    
    static func availableForSettingAmount(address: String, token: Token) -> Bool {
        switch token.chainID {
        case ChainID.lightning:
            true
        default:
            DepositLink.native(address: address, token: token, limitation: nil, amount: 1) != nil
        }
    }
    
}

extension DepositLink {
    
    struct Mixin {
        
        struct Specification {
            let token: Token
            let amount: Decimal
        }
        
        let account: Account
        let specification: Specification?
        
    }
    
    static func mixin(account: Account, specification: Mixin.Specification? = nil) -> DepositLink {
        let chain = Mixin(account: account, specification: specification)
        var link = "https://mixin.one/pay/\(account.userID)"
        if let specification {
            link.append("?asset=\(specification.token.assetID)&amount=\(specification.amount)")
        }
        return DepositLink(chain: .mixin(chain), value: link)
    }
    
}

extension DepositLink {
    
    struct Native {
        let address: String
        let token: Token
        let limitation: DepositAmountLimitation?
        let amount: Decimal?
    }
    
    static func native(
        address: String,
        token: Token,
        limitation: DepositAmountLimitation?
    ) -> DepositLink {
        let context = Native(
            address: address,
            token: token,
            limitation: limitation,
            amount: nil
        )
        return DepositLink(chain: .native(context), value: address)
    }
    
    static func native(
        address: String,
        token: Token,
        limitation: DepositAmountLimitation?,
        amount: Decimal
    ) -> DepositLink? {
        var value: String
        if let chain = Web3Chain.chain(chainID: token.chainID) {
            switch chain.specification {
            case .bitcoin:
                value = "bitcoin:\(address)?amount=\(amount)"
            case .evm(let id):
                if token.assetID == token.chainID {
                    value = "ethereum:\(address)"
                    if id != 1 {
                        value.append("@\(id)")
                    }
                    value.append("?value=\(amount / .wei)")
                } else if let positionalValue = token.positionalValue {
                    value = "ethereum:\(token.assetKey)"
                    if id != 1 {
                        value.append("@\(id)")
                    }
                    value.append("/transfer?address=\(address)&amount=\(amount)&uint256=\(amount * positionalValue)")
                } else {
                    ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
                    return nil
                }
            case .solana:
                value = "solana:\(address)?amount=\(amount)"
                if token.assetID != AssetID.sol {
                    value.append("&spl-token=\(token.assetKey)&token=\(token.assetKey)")
                }
            }
        } else {
            switch token.chainID {
            case ChainID.monero:
                value = "monero:\(address)?tx_amount=\(amount)"
            case ChainID.ton:
                switch token.assetID {
                case AssetID.ton:
                    value = "ton://transfer/\(address)?amount=\(amount / .nanoton)"
                default:
                    if let positionalValue = token.positionalValue {
                        value = "ton://transfer/\(address)?jetton=\(token.assetKey)&amount=\(amount * positionalValue)"
                    } else {
                        ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
                        return nil
                    }
                }
            case ChainID.bitcoin:
                value = "bitcoin:\(address)?amount=\(amount)"
            case ChainID.litecoin:
                value = "litecoin:\(address)?amount=\(amount)"
            case ChainID.dogecoin:
                value = "dogecoin:\(address)?amount=\(amount)"
            case ChainID.dash:
                value = "dash:\(address)?amount=\(amount)"
            case ChainID.lightning:
                value = address
            default:
                return nil
            }
        }
        let context = Native(address: address, token: token, limitation: limitation, amount: amount)
        return DepositLink(chain: .native(context), value: value)
    }
    
}
