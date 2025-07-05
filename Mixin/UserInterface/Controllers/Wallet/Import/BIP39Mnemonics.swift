import Foundation
import web3
import MixinServices
import TIP

struct BIP39Mnemonics {
    
    enum PhrasesCount: Int, CaseIterable {
        case medium = 12
        case long = 24
    }
    
    enum InitError: Error {
        case invalidPhrasesCount
        case invalidPhrase
    }
    
    private let phrases: String
    private let evmMasterKey: ExtendedKey
    private let solMasterKey: ExtendedKey
    
    init(phrases: [String]) throws {
        guard PhrasesCount(rawValue: phrases.count) != nil else {
            throw InitError.invalidPhrasesCount
        }
        guard phrases.allSatisfy(BIP39.wordSet.contains(_:)) else {
            throw InitError.invalidPhrase
        }
        let joinedPhrases = phrases.joined(separator: " ")
        let seed = try PBKDF2.derivation(
            password: joinedPhrases,
            salt: "mnemonic",
            pseudoRandomAlgorithm: .hmacSHA512,
            iterationCount: 2048,
            keyCount: 64
        )
        self.phrases = joinedPhrases
        self.evmMasterKey = ExtendedKey(seed: seed, curve: .secp256k1)
        self.solMasterKey = ExtendedKey(seed: seed, curve: .ed25519)
    }
    
}

extension BIP39Mnemonics {
    
    struct Derivation {
        let privateKey: Data
        let address: String
    }
    
    struct DerivedWallet {
        let evm: Derivation
        let solana: Derivation
    }
    
    enum DerivationError: Error {
        case mismatchedEVMAddress
        case mismatchedSolanaAddress
    }
    
    func deriveWallets(indices: ClosedRange<UInt32>) throws -> [DerivedWallet] {
        var error: NSError?
        return try indices.map { (index: UInt32) in
            let evmKey = try evmMasterKey
                .privateKeyUsingSecp256k1(index: .hardened(44))
                .privateKeyUsingSecp256k1(index: .hardened(60))
                .privateKeyUsingSecp256k1(index: .hardened(0))
                .privateKeyUsingSecp256k1(index: .normal(0))
                .privateKeyUsingSecp256k1(index: .normal(index))
            let keyStorage = InPlaceKeyStorage(raw: evmKey.key)
            let account = try EthereumAccount(keyStorage: keyStorage)
            let evmAddress = account.address.toChecksumAddress()
            let redundantEVMAddress = BlockchainGenerateEvmAddressFromMnemonic(
                phrases,
                "m/44'/60'/0'/0/\(index)",
                &error
            )
            if let error {
                throw error
            } else if evmAddress != redundantEVMAddress {
                throw DerivationError.mismatchedEVMAddress
            }
            
            let solanaKey = solMasterKey
                .privateKeyUsingEd25519(hardeningIndex: 44)
                .privateKeyUsingEd25519(hardeningIndex: 501)
                .privateKeyUsingEd25519(hardeningIndex: index)
                .privateKeyUsingEd25519(hardeningIndex: 0)
            let solanaAddress = try Solana.publicKey(seed: solanaKey.key)
            let redundantSolanaAddress = BlockchainGenerateSolanaAddressFromMnemonic(
                phrases,
                "m/44'/501'/\(index)'/0'",
                &error
            )
            if let error {
                throw error
            } else if solanaAddress != redundantSolanaAddress {
                throw DerivationError.mismatchedSolanaAddress
            }
            
            let evm = Derivation(privateKey: evmKey.key, address: evmAddress)
            let solana = Derivation(privateKey: solanaKey.key, address: solanaAddress)
            return DerivedWallet(evm: evm, solana: solana)
        }
    }
    
}
