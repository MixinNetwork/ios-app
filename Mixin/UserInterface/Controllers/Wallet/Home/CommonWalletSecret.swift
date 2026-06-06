import Foundation

enum CommonWalletSecret {
    case mnemonics(EncryptedBIP39Mnemonics)
    case privateKey(EncryptedPrivateKey, Web3Chain.Kind)
}
