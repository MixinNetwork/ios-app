import Foundation

enum ImportedSecret {
    case mnemonics(EncryptedBIP39Mnemonics)
    case privateKeyFromMnemonics(EncryptedBIP39Mnemonics, Web3Chain.Kind, DerivationPath)
}
