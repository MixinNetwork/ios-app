import Foundation
import MixinServices

extension Web3Wallet {
    
    enum Availability {
        case always
        case never
        case afterImportingMnemonics
        case afterImportingPrivateKey
    }
    
}
