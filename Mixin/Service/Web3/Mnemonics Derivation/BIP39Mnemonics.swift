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
        case invalidPhrases
        case invalidEntropy
        case invalidEntropyCount
    }
    
    let entropy: Data
    let phrases: [String]
    let joinedPhrases: String
    
    private let evmMasterKey: ExtendedKey
    private let solMasterKey: ExtendedKey
    
    init(phrases: [String]) throws {
        guard PhrasesCount(rawValue: phrases.count) != nil else {
            throw InitError.invalidPhrasesCount
        }
        guard let entropy = BIP39.entropy(from: phrases) else {
            throw InitError.invalidPhrases
        }
        try self.init(entropy: entropy, phrases: phrases)
    }
    
    init(entropy: Data) throws {
        guard let phrases = BIP39.mnemonics(from: entropy) else {
            throw InitError.invalidEntropy
        }
        guard let _ = PhrasesCount(rawValue: phrases.count) else {
            throw InitError.invalidEntropyCount
        }
        try self.init(entropy: entropy, phrases: phrases)
    }
    
    private init(entropy: Data, phrases: [String]) throws {
        let joinedPhrases = phrases.joined(separator: " ")
        let seed = try PBKDF2.derivation(
            password: joinedPhrases,
            salt: "mnemonic",
            pseudoRandomAlgorithm: .hmacSHA512,
            iterationCount: 2048,
            keyCount: 64
        )
        self.entropy = entropy
        self.phrases = phrases
        self.joinedPhrases = joinedPhrases
        self.evmMasterKey = ExtendedKey(seed: seed, curve: .secp256k1)
        self.solMasterKey = ExtendedKey(seed: seed, curve: .ed25519)
    }
    
}

extension BIP39Mnemonics {
    
    struct Derivation {
        let privateKey: Data
        let address: String
        let path: DerivationPath
    }
    
    struct DerivedWallet {
        let evm: Derivation
        let solana: Derivation
    }
    
    enum DerivationError: Error {
        case mismatchedEVMAddress
        case mismatchedSolanaAddress
    }
    
    func deriveForEVM(path: DerivationPath) throws -> Derivation {
        var error: NSError?
        let privateKey = try evmMasterKey.deriveUsingSecp256k1(path: path)
        let keyStorage = InPlaceKeyStorage(raw: privateKey.key)
        let account = try EthereumAccount(keyStorage: keyStorage)
        let evmAddress = account.address.toChecksumAddress()
        let redundantEVMAddress = BlockchainGenerateEvmAddressFromMnemonic(
            joinedPhrases,
            path.string,
            &error
        )
        if let error {
            throw error
        } else if evmAddress != redundantEVMAddress {
            throw DerivationError.mismatchedEVMAddress
        }
        return Derivation(privateKey: privateKey.key, address: evmAddress, path: path)
    }
    
    func deriveForSolana(path: DerivationPath) throws -> Derivation {
        var error: NSError?
        let solanaKey = solMasterKey.deriveUsingEd25519(path: path)
        let solanaAddress = try Solana.publicKey(seed: solanaKey.key)
        let redundantSolanaAddress = BlockchainGenerateSolanaAddressFromMnemonic(
            joinedPhrases,
            path.string,
            &error
        )
        if let error {
            throw error
        } else if solanaAddress != redundantSolanaAddress {
            throw DerivationError.mismatchedSolanaAddress
        }
        return Derivation(privateKey: solanaKey.key, address: solanaAddress, path: path)
    }
    
    func deriveWallets(indices: ClosedRange<UInt32>) throws -> [DerivedWallet] {
        try indices.map { (index: UInt32) in
            let evmPath = try DerivationPath(string: "m/44'/60'/0'/0/\(index)")
            let evmDerivation = try deriveForEVM(path: evmPath)
            
            let solanaPath = try DerivationPath(string: "m/44'/501'/\(index)'/0'")
            let solanaDerivation = try deriveForSolana(path: solanaPath)
            
            return DerivedWallet(evm: evmDerivation, solana: solanaDerivation)
        }
    }
    
}
