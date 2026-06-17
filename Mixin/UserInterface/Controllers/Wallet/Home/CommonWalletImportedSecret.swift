import Foundation

enum CommonWalletImportedSecret {
    case mnemonics(EncryptedBIP39Mnemonics)
    case privateKey(EncryptedPrivateKey, Web3Chain.Kind)
}
