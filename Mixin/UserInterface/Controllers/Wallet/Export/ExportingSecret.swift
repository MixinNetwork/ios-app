import Foundation

enum ExportingSecret {
    case mnemonics(EncryptedBIP39Mnemonics)
    case privateKeyFromMnemonics(EncryptedBIP39Mnemonics, Web3Chain.Kind, DerivationPath)
    case privateKey(EncryptedPrivateKey, Web3Chain.Kind)
}
