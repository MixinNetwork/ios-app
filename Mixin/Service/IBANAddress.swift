import Foundation

struct IBANAddress {
    
    let standarizedAddress: String
    
    init?(string: String) {
        guard string.hasPrefix("iban:XE") || string.hasPrefix("IBAN:XE") else {
            return nil
        }
        guard string.count >= 20 else {
            return nil
        }
        
        let startIndex = string.index(string.startIndex, offsetBy: 9)
        let endIndex = string.firstIndex(of: "?") ?? string.endIndex
        let accountIdentifier = string[startIndex..<endIndex].lowercased()
        
        guard let address = Self.base36ToHex(accountIdentifier) else {
            return nil
        }
        standarizedAddress = "0x\(address)"
    }
    
    private static func base36ToHex(_ base36: String) -> String? {
        let base36Alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
        let base36AlphabetMap = {
            var reverseLookup = [Character: Int]()
            for characterIndex in 0..<base36Alphabet.count {
                let character = base36Alphabet[base36Alphabet.index(base36Alphabet.startIndex, offsetBy: characterIndex)]
                reverseLookup[character] = characterIndex
            }
            return reverseLookup
        }()
        var bytes = [Int]()
        for character in base36 {
            guard var carry = base36AlphabetMap[character] else {
                return nil
            }
            
            for byteIndex in 0..<bytes.count {
                carry += bytes[byteIndex] * 36
                bytes[byteIndex] = carry & 0xff
                carry >>= 8
            }
            
            while carry > 0 {
                bytes.append(carry & 0xff)
                carry >>= 8
            }
        }
        return bytes.reversed().map { String(format: "%02hhx", $0) }.joined()
    }
    
}
