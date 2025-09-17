import UIKit
import MixinServices

struct DepositLink {
    
    typealias Token = any (OnChainToken & ValuableToken)
    
    struct Mixin {
        
        struct Specification {
            let token: Token
            let amount: Decimal
        }
        
        let account: Account
        let specification: Specification?
        
    }
    
    struct Native {
        let address: String
        let token: Token
        let minimumDeposit: String?
        let amount: Decimal?
    }
    
    enum Chain {
        case mixin(Mixin)
        case native(Native)
    }
    
    let chain: Chain
    let textValue: String
    let qrCodeValue: String // Could be different from `textValue`. For example, in lightning network the `qrCodeValue` is uppercased.
    
    static func mixin(account: Account, specification: Mixin.Specification? = nil) -> DepositLink {
        let chain = Mixin(account: account, specification: specification)
        var link = "https://mixin.one/pay/\(account.userID)"
        if let specification {
            link.append("?asset=\(specification.token.assetID)&amount=\(specification.amount)")
        }
        return DepositLink(chain: .mixin(chain), textValue: link, qrCodeValue: link)
    }
    
    static func native(address: String, token: Token, minimumDeposit: String?) -> DepositLink {
        let context = Native(address: address, token: token, minimumDeposit: minimumDeposit, amount: nil)
        let qrCodeValue = switch token.chainID {
        case ChainID.lightning:
            address.uppercased()
        default:
            address
        }
        return DepositLink(chain: .native(context), textValue: address, qrCodeValue: qrCodeValue)
    }
    
    static func native(address: String, token: Token, amount: Decimal) -> DepositLink? {
        var value: String
        if let chain = Web3Chain.chain(chainID: token.chainID) {
            switch chain.specification {
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
            default:
                return nil
            }
        }
        let context = Native(address: address, token: token, minimumDeposit: nil, amount: amount)
        return DepositLink(chain: .native(context), textValue: value, qrCodeValue: value)
    }
    
    static func availableForSettingAmount(address: String, token: Token) -> Bool {
        let link = DepositLink.native(address: address, token: token, amount: 1)
        return link != nil
    }
    
    func replacing(token: Token, amount: Decimal) -> DepositLink? {
        switch chain {
        case .mixin(let context):
                .mixin(
                    account: context.account,
                    specification: .init(token: token, amount: amount)
                )
        case .native(let context):
                .native(
                    address: context.address,
                    token: token,
                    amount: amount
                )
        }
    }
    
}
