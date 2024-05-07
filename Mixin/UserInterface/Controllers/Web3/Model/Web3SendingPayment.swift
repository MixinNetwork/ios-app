import Foundation
import MixinServices

class Web3SendingTokenPayment {
    
    let chain: Web3Chain
    let token: Web3Token
    let fromAddress: String
    
    var sendingNativeToken: Bool {
        switch (token.chainID, token.assetKey) {
        case ("ethereum",           "0x0000000000000000000000000000000000000000"),
            ("base",                "0x0000000000000000000000000000000000000000"),
            ("arbitrum",            "0x0000000000000000000000000000000000000000"),
            ("optimism",            "0x0000000000000000000000000000000000000000"),
            ("polygon",             "0x0000000000000000000000000000000000001010"),
            ("binance-smart-chain", "0x0000000000000000000000000000000000000000"),
            ("avalanche",           "0x0000000000000000000000000000000000000000"):
            return true
        default:
            return false
        }
    }
    
    init(chain: Web3Chain, token: Web3Token, fromAddress: String) {
        self.chain = chain
        self.token = token
        self.fromAddress = fromAddress
    }
    
}

class Web3SendingTokenToAddressPayment: Web3SendingTokenPayment {
    
    enum AddressType {
        case mixinWallet
        case arbitrary
    }
    
    let toType: AddressType
    let toAddress: String // Always the receiver. The contract address is filled in further steps.
    let toAddressCompactRepresentation: String
    
    init(payment: Web3SendingTokenPayment, to type: AddressType, address: String) {
        self.toType = type
        self.toAddress = address
        self.toAddressCompactRepresentation = Address.compactRepresentation(of: address)
        super.init(chain: payment.chain,
                   token: payment.token,
                   fromAddress: payment.fromAddress)
    }
    
}
