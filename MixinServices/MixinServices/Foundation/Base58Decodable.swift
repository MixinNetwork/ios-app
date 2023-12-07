import Foundation

// Basically a Swift translation of base58.cpp in bitcoin, with the only difference
// being the handling of whitespaces. No spaces are accepted at any position.
// See https://github.com/bitcoin/bitcoin/blob/306ccd4927a2efe325c8d84be1bdb79edeb29b04/src/base58.cpp
// Permanent https://github.com/bitcoin/bitcoin/blob/master/src/base58.cpp

fileprivate let mapBase58: [Int] = [
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1, 0, 1, 2, 3, 4, 5, 6,  7, 8,-1,-1,-1,-1,-1,-1,
    -1, 9,10,11,12,13,14,15, 16,-1,17,18,19,20,21,-1,
    22,23,24,25,26,27,28,29, 30,31,32,-1,-1,-1,-1,-1,
    -1,33,34,35,36,37,38,39, 40,41,42,43,-1,44,45,46,
    47,48,49,50,51,52,53,54, 55,56,57,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
]

extension Data {
    
    public init?<String: StringProtocol>(base58EncodedString string: String) where String.Element == Character {
        guard !string.isEmpty else {
            return nil
        }
        var index = string.startIndex
        
        var zeroes = 0
        var length = 0
        while index < string.endIndex, string[index] == "1" {
            zeroes += 1
            index = string.index(after: index)
        }
        
        let size = (string.distance(from: index, to: string.endIndex)) * 733 / 1000 + 1
        var buffer = Data(count: size)
        
        assert(mapBase58.count == 256)
        while index != string.endIndex {
            guard let characterASCIIValue = string[index].asciiValue else {
                return nil
            }
            var carry = mapBase58[Int(characterASCIIValue)]
            if carry == -1 {
                return nil
            }
            var i = 0
            for it in stride(from: size - 1, through: 0, by: -1) where carry != 0 || i < length {
                carry += 58 * Int(buffer[it])
                buffer[it] = UInt8(carry % 256)
                carry /= 256
                i += 1
            }
            assert(carry == 0)
            length = i
            index = string.index(after: index)
        }
        
        self.init(count: zeroes + length)
        replaceSubrange(zeroes..<zeroes + length, with: buffer[size - length..<size])
    }
    
}
