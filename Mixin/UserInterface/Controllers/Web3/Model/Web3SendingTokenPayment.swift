import Foundation
import MixinServices

class Web3SendingTokenPayment {
    
    let wallet: Web3Wallet
    let chain: Web3Chain
    let token: Web3TokenItem
    let fromAddress: Web3Address
    let sendingNativeToken: Bool
    
    init(
        wallet: Web3Wallet,
        chain: Web3Chain,
        token: Web3TokenItem,
        fromAddress: Web3Address
    ) {
        self.wallet = wallet
        self.chain = chain
        self.token = token
        self.fromAddress = fromAddress
        self.sendingNativeToken = switch (token.chainID, token.assetKey) {
        case (ChainID.solana,           Web3Token.AssetKey.sol),
            (ChainID.ethereum,          Web3Token.AssetKey.eth),
            (ChainID.base,              "0x0000000000000000000000000000000000000000"),
            (ChainID.arbitrum,          "0x0000000000000000000000000000000000000000"),
            (ChainID.optimism,          "0x0000000000000000000000000000000000000000"),
            (ChainID.polygon,           "0x0000000000000000000000000000000000000000"),
            (ChainID.polygon,           "0x0000000000000000000000000000000000001010"),
            (ChainID.bnbSmartChain,     "0x0000000000000000000000000000000000000000"),
            (ChainID.avalancheXChain,   "0x0000000000000000000000000000000000000000"):
            true
        default:
            false
        }
    }
    
}

final class Web3SendingTokenToAddressPayment: Web3SendingTokenPayment {
    
    enum AddressType {
        
        case addressBook(label: String)
        case privacyWallet
        case commonWallet(name: String)
        case arbitrary
        
        var addressLabel: String? {
            switch self {
            case let .addressBook(label):
                label
            case .privacyWallet:
                R.string.localizable.privacy_wallet()
            case let .commonWallet(name):
                name
            case .arbitrary:
                nil
            }
        }
        
    }
    
    let toType: AddressType
    let toAddress: String // Always the receiver, not the contract address
    let toAddressCompactRepresentation: String
    
    init(payment: Web3SendingTokenPayment, to type: AddressType, address: String) {
        self.toType = type
        self.toAddress = address
        self.toAddressCompactRepresentation = Address.compactRepresentation(of: address)
        super.init(
            wallet: payment.wallet,
            chain: payment.chain,
            token: payment.token,
            fromAddress: payment.fromAddress
        )
    }
    
}
