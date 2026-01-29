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
    
    private let secp256k1MasterKey: ExtendedKey
    private let ed25519MasterKey: ExtendedKey
    
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
        self.secp256k1MasterKey = ExtendedKey(seed: seed, curve: .secp256k1)
        self.ed25519MasterKey = ExtendedKey(seed: seed, curve: .ed25519)
    }
    
}

extension BIP39Mnemonics {
    
    struct Derivation {
        let privateKey: Data
        let address: String
        let path: DerivationPath
    }
    
    struct DerivedWallet {
        let bitcoin: Derivation
        let evm: Derivation
        let solana: Derivation
    }
    
    enum DerivationError: Error {
        case mismatchedBitcoinAddress
        case mismatchedEVMAddress
        case mismatchedSolanaAddress
    }
    
    func checkedDerivationForBitcoin(path: DerivationPath) throws -> Derivation {
        var error: NSError?
        let privateKey = try Bitcoin.privateKey(mnemonics: joinedPhrases, path: path.string)
        let address = try Bitcoin.segwitAddress(privateKey: privateKey)
        let redundantAddress = BlockchainGenerateBitcoinSegwitAddressFromMnemonic(
            joinedPhrases,
            path.string,
            &error
        )
        if let error {
            throw error
        } else if address != redundantAddress {
            throw DerivationError.mismatchedBitcoinAddress
        } else {
            return Derivation(privateKey: privateKey, address: address, path: path)
        }
    }
    
    func checkedDerivationForEVM(path: DerivationPath) throws -> Derivation {
        var error: NSError?
        let privateKey = try secp256k1MasterKey.deriveUsingSecp256k1(path: path)
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
    
    func checkedDerivationForSolana(path: DerivationPath) throws -> Derivation {
        var error: NSError?
        let solanaKey = ed25519MasterKey.deriveUsingEd25519(path: path)
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
            let bitcoinPath = try DerivationPath.bitcoin(index: index)
            let bitcoinDerivation = try checkedDerivationForBitcoin(path: bitcoinPath)
            
            let evmPath = try DerivationPath.evm(index: index)
            let evmDerivation = try checkedDerivationForEVM(path: evmPath)
            
            let solanaPath = try DerivationPath.solana(index: index)
            let solanaDerivation = try checkedDerivationForSolana(path: solanaPath)
            
            return DerivedWallet(
                bitcoin: bitcoinDerivation,
                evm: evmDerivation,
                solana: solanaDerivation
            )
        }
    }
    
}
