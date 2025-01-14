import Foundation
import MixinServices
import TIP

enum MIXAddress {
    
    case user(String)
    case multisig(threshold: Int32, userIDs: [String])
    case mainnet(String)
    
    init?(string: String) {
        let header = "MIX"
        let headerData = header.data(using: .utf8)!
        
        guard string.hasPrefix(header) else {
            return nil
        }
        guard string.count > header.count else {
            Logger.general.debug(category: "MIXAddress", message: "Invalid count: \(string.count)")
            return nil
        }
        
        let base58Encoded = string.suffix(string.count - header.count)
        guard let data = Data(base58EncodedString: base58Encoded) else {
            Logger.general.debug(category: "MIXAddress", message: "Base58 decoding failed: \(base58Encoded)")
            return nil
        }
        guard data.count > 7 else {
            Logger.general.debug(category: "MIXAddress", message: "Invalid data count: \(data.count)")
            return nil
        }
        
        let checksumCount = 4
        let payload = data.prefix(data.count - checksumCount)
        let providedChecksum = data.suffix(checksumCount)
        guard let calculatedChecksum = SHA3_256.hash(data: headerData + payload)?.prefix(checksumCount) else {
            Logger.general.debug(category: "MIXAddress", message: "Unable to hash")
            return nil
        }
        guard providedChecksum == calculatedChecksum else {
            Logger.general.debug(category: "MIXAddress", message: "Invalid checksum")
            return nil
        }
        
        self.init(data: payload)
    }
    
    init?(data payload: Data) {
        let version: UInt8 = 2
        let payloadVersion: UInt8 = payload[payload.startIndex]
        guard version == payloadVersion else {
            Logger.general.debug(category: "MIXAddress", message: "Unknown version")
            return nil
        }
        
        let threshold: UInt8 = payload[payload.startIndex.advanced(by: 1)]
        let membersCount: Int = Int(payload[payload.startIndex.advanced(by: 2)])
        guard threshold != 0 && threshold <= membersCount && membersCount <= 64 else {
            Logger.general.debug(category: "MIXAddress", message: "Invalid threshold: \(threshold), total: \(membersCount)")
            return nil
        }
        
        let membersData = payload[payload.startIndex.advanced(by: 3)...]
        switch membersData.count {
        case 16 * membersCount:
            let userIDs = (0..<membersCount).map { i in
                let startIndex = membersData.startIndex.advanced(by: i * UUID.dataCount)
                let endIndex = startIndex.advanced(by: UUID.dataCount)
                let data = membersData[startIndex..<endIndex]
                let uuid = UUID(data: data)
                return uuid.uuidString.lowercased()
            }
            if userIDs.count == 1 {
                self = .user(userIDs[0])
            } else {
                self = .multisig(threshold: Int32(threshold), userIDs: userIDs.sorted(by: <))
            }
        case 64 * membersCount:
            let addresses = (0..<membersCount).map { i in
                let spendKeyCount = 32
                let viewKeyCount = 32
                
                let spendKeyStartIndex = membersData.startIndex.advanced(by: i * (spendKeyCount + viewKeyCount))
                let spendKeyEndIndex = spendKeyStartIndex.advanced(by: spendKeyCount)
                let spendKey = membersData[spendKeyStartIndex..<spendKeyEndIndex]
                
                let viewKeyStartIndex = spendKeyEndIndex
                let viewKeyEndIndex = spendKeyEndIndex.advanced(by: viewKeyCount)
                let viewKey = membersData[viewKeyStartIndex..<viewKeyEndIndex]
                
                let address = KernelAddress()
                address.setPublicSpendKey(spendKey)
                address.setPublicViewKey(viewKey)
                return address
            }
            guard let firstAddress = addresses.first else {
                return nil
            }
            self = .mainnet(firstAddress.string())
        default:
            Logger.general.debug(category: "MIXAddress", message: "Invalid members count: \(membersData.count)")
            return nil
        }
    }
    
}
