import Foundation

extension UUID {
    
    public var data: Data {
        Data([
            uuid.0,  uuid.1,  uuid.2,  uuid.3,
            uuid.4,  uuid.5,  uuid.6,  uuid.7,
            uuid.8,  uuid.9,  uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15
        ])
    }
    
    public init(data: Data) {
        assert(data.count == 16)
        let uuid: uuid_t = (
            data[data.startIndex],
            data[data.startIndex.advanced(by: 1)],
            data[data.startIndex.advanced(by: 2)],
            data[data.startIndex.advanced(by: 3)],
            data[data.startIndex.advanced(by: 4)],
            data[data.startIndex.advanced(by: 5)],
            data[data.startIndex.advanced(by: 6)],
            data[data.startIndex.advanced(by: 7)],
            data[data.startIndex.advanced(by: 8)],
            data[data.startIndex.advanced(by: 9)],
            data[data.startIndex.advanced(by: 10)],
            data[data.startIndex.advanced(by: 11)],
            data[data.startIndex.advanced(by: 12)],
            data[data.startIndex.advanced(by: 13)],
            data[data.startIndex.advanced(by: 14)],
            data[data.startIndex.advanced(by: 15)]
        )
        self = UUID(uuid: uuid)
    }
    
    public static func isValidUUIDString(_ string: String) -> Bool {
        UUID(uuidString: string) != nil
    }
    
    public static func isValidLowercasedUUIDString(_ string: String) -> Bool {
        UUID(uuidString: string) != nil && string.allSatisfy { !$0.isUppercase }
    }
    
    public static func uniqueObjectIDString(_ inputs: String...) -> String {
        let input = inputs.joined()
        let dash = "-".utf16.first!
        
        var digest = input.utf8.md5.data
        digest[6] &= 0x0f       // clear version
        digest[6] |= 0x30       // set to version 3
        digest[8] &= 0x3f       // clear variant
        digest[8] |= 0x80       // set to IETF variant
        
        var characters: [unichar] = []
        characters.reserveCapacity(2 * digest.count + 4)
        for (index, value) in digest.enumerated() {
            let (high, low) = value.hexEncodedUnichars()
            characters.append(high)
            characters.append(low)
            if index == 3 || index == 5 || index == 7 || index == 9 {
                characters.append(dash)
            }
        }
        
        return String(utf16CodeUnits: characters, count: characters.count)
    }
    
}
