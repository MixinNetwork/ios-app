import Foundation
import MixinServices

struct WalletCandidate {
    
    let evmWallet: BIP39Mnemonics.Derivation
    let solanaWallet: BIP39Mnemonics.Derivation
    let usdBalanceSum: Decimal
    let value: NSAttributedString
    let tokens: [TokenDigest]
    
    init(
        evmWallet: BIP39Mnemonics.Derivation,
        solanaWallet: BIP39Mnemonics.Derivation,
        tokens: [Web3Token]
    ) {
        let usdBalanceSum = tokens.reduce(0) { result, token in
            result + token.decimalUSDBalance
        }
        let value = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: usdBalanceSum,
            fontSize: 22
        )
        let tokenDigests = tokens.map(TokenDigest.init(token:))
        self.init(
            evmWallet: evmWallet,
            solanaWallet: solanaWallet,
            usdBalanceSum: usdBalanceSum,
            value: value,
            tokens: tokenDigests
        )
    }
    
    private init(
        evmWallet: BIP39Mnemonics.Derivation, solanaWallet: BIP39Mnemonics.Derivation,
        usdBalanceSum: Decimal, value: NSAttributedString, tokens: [TokenDigest]
    ) {
        self.evmWallet = evmWallet
        self.solanaWallet = solanaWallet
        self.usdBalanceSum = usdBalanceSum
        self.value = value
        self.tokens = tokens
    }
    
    static func empty(
        evmWallet: BIP39Mnemonics.Derivation,
        solanaWallet: BIP39Mnemonics.Derivation
    ) -> WalletCandidate {
        let value = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: 0,
            fontSize: 22
        )
        return WalletCandidate(
            evmWallet: evmWallet,
            solanaWallet: solanaWallet,
            usdBalanceSum: 0,
            value: value,
            tokens: []
        )
    }
    
}
