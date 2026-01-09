import Foundation
import MixinServices

struct WalletCandidate {
    
    let bitcoinWallet: BIP39Mnemonics.Derivation
    let evmWallet: BIP39Mnemonics.Derivation
    let solanaWallet: BIP39Mnemonics.Derivation
    let usdBalanceSum: Decimal
    let value: NSAttributedString
    let tokens: [TokenDigest]
    let importedAsName: String?
    
    var isImportable: Bool {
        importedAsName == nil
    }
    
    init(
        bitcoinWallet: BIP39Mnemonics.Derivation,
        evmWallet: BIP39Mnemonics.Derivation,
        solanaWallet: BIP39Mnemonics.Derivation,
        tokens: [Web3Token],
        importedAsName: String?
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
            bitcoinWallet: bitcoinWallet,
            evmWallet: evmWallet,
            solanaWallet: solanaWallet,
            usdBalanceSum: usdBalanceSum,
            value: value,
            tokens: tokenDigests,
            importedAsName: importedAsName
        )
    }
    
    private init(
        bitcoinWallet: BIP39Mnemonics.Derivation,
        evmWallet: BIP39Mnemonics.Derivation,
        solanaWallet: BIP39Mnemonics.Derivation,
        usdBalanceSum: Decimal,
        value: NSAttributedString,
        tokens: [TokenDigest],
        importedAsName: String?
    ) {
        self.bitcoinWallet = bitcoinWallet
        self.evmWallet = evmWallet
        self.solanaWallet = solanaWallet
        self.usdBalanceSum = usdBalanceSum
        self.value = value
        self.tokens = tokens
        self.importedAsName = importedAsName
    }
    
    static func empty(
        bitcoinWallet: BIP39Mnemonics.Derivation,
        evmWallet: BIP39Mnemonics.Derivation,
        solanaWallet: BIP39Mnemonics.Derivation,
        importedAsName: String?,
    ) -> WalletCandidate {
        let value = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: 0,
            fontSize: 22
        )
        return WalletCandidate(
            bitcoinWallet: bitcoinWallet,
            evmWallet: evmWallet,
            solanaWallet: solanaWallet,
            usdBalanceSum: 0,
            value: value,
            tokens: [],
            importedAsName: importedAsName
        )
    }
    
}
