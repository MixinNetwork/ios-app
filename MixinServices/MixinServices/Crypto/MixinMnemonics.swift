import Foundation
import zlib
import TIP

public struct MixinMnemonics {
    
    // Contains extra checksum
    public enum PhrasesCount: Int, CaseIterable {
        case `default` = 13
        case legacy = 25
    }
    
    public enum EntropyCount: Int, CaseIterable {
        case `default` = 16
        case legacy = 32
    }
    
    enum InitError: Error {
        case invalidEntropy
        case invalidEntropyCount
        case invalidChecksum
        case invalidPhrasesCount
        case invalidPhrases
        case mismatchedBIP39Validity
        case mismatchedMnemonics
        case mismatchedChecksum
        case generateRandomData
    }
    
    public let entropy: Data
    public let phrases: [String]    // Contains extra checksum
    public let bip39: String        // Standard BIP-0039 string from `entropy`
    
    public var joinedPhrases: String {
        phrases.joined(separator: " ")
    }
    
    public init(entropy: Data) throws {
        guard let bip39Phrases = BIP39.mnemonics(from: entropy) else {
            throw InitError.invalidEntropy
        }
        
        // 1 for the extra checksum
        guard let _ = PhrasesCount(rawValue: bip39Phrases.count + 1) else {
            throw InitError.invalidEntropyCount
        }
        
        let bip39 = bip39Phrases.joined(separator: " ")
        let goMnemonics = try {
            var error: NSError?
            let mnemonics = BlockchainNewMnemonic(entropy, &error)
            if let error {
                throw error
            }
            return mnemonics
        }()
        guard bip39 == goMnemonics else {
            throw InitError.mismatchedMnemonics
        }
        
        let checksum = Self.checksum(bip39Phrases: bip39Phrases)
        let goChecksum = BlockchainMnemonicChecksumWord(bip39, 3)
        guard checksum == goChecksum else {
            throw InitError.mismatchedChecksum
        }
        
        self.entropy = entropy
        self.phrases = bip39Phrases + [checksum]
        self.bip39 = bip39
    }
    
    public init(phrases: [String]) throws {
        guard let _ = PhrasesCount(rawValue: phrases.count) else {
            throw InitError.invalidPhrasesCount
        }
        
        var bip39Phrases = phrases
        let inputChecksum = bip39Phrases.removeLast()
        let expectedChecksum = Self.checksum(bip39Phrases: bip39Phrases)
        guard inputChecksum == expectedChecksum else {
            throw InitError.invalidChecksum
        }
        
        guard let entropy = BIP39.entropy(from: bip39Phrases) else {
            throw InitError.invalidPhrases
        }
        let bip39 = bip39Phrases.joined(separator: " ")
        
        let goChecksum = BlockchainMnemonicChecksumWord(bip39, 3)
        guard inputChecksum == goChecksum else {
            throw InitError.mismatchedChecksum
        }
        guard BlockchainIsMnemonicValid(bip39) else {
            throw InitError.mismatchedBIP39Validity
        }
        
        self.entropy = entropy
        self.phrases = phrases
        self.bip39 = bip39
    }
    
    public static func random(count: EntropyCount = .default) throws -> MixinMnemonics {
        
        func randomMnemonics() throws -> MixinMnemonics {
            guard let entropy = Data(withNumberOfSecuredRandomBytes: count.rawValue) else {
                throw InitError.generateRandomData
            }
            return try MixinMnemonics(entropy: entropy)
        }
        
        var mnemonics = try randomMnemonics()
        while mnemonics.hasDuplicatedPhrases() {
            mnemonics = try randomMnemonics()
        }
        
#if DEBUG
        Logger.general.debug(category: "Mnemonics", message: "Generated Mnemonics: \(mnemonics.phrases.joined(separator: " "))")
#endif
        return mnemonics
    }
    
    public static func areValid(phrases: [String]) -> Bool {
        do {
            guard let phrasesCount = PhrasesCount(rawValue: phrases.count) else {
                throw InitError.invalidPhrasesCount
            }
            let mnemonics = try MixinMnemonics(phrases: phrases)
            switch phrasesCount {
            case .default:
                return !mnemonics.hasDuplicatedPhrases()
            case .legacy:
                return true
            }
        } catch {
            return false
        }
    }
    
    private static func checksum(bip39Phrases phrases: [String]) -> String {
        let sum = phrases.map({ $0.prefix(3) }).joined()
        let byteCount = sum.lengthOfBytes(using: .utf8)
        let crc = crc32(0, sum, uInt(byteCount))
        let index = Int(crc) % BIP39.wordlist.count
        return BIP39.wordlist[index]
    }
    
    public func hasDuplicatedPhrases() -> Bool {
        Set(phrases).count != phrases.count
    }
    
}

extension MixinMnemonics: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entropy == rhs.entropy
    }
    
}
