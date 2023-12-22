import Foundation
import MixinServices
import Tip

struct SafePaymentURL {
    
    private static let schemes = ["mixin", "https"]
    private static let host = "mixin.one"
    
    enum Address {
        case user(String)
        case multisig(threshold: Int32, userIDs: [String])
        case mainnet(String)
    }
    
    struct Request {
        let asset: String
        let amount: Decimal
    }
    
    let address: Address
    let request: Request?
    let memo: String
    let trace: String
    let redirection: URL?
    
    init?(url: URL) {
        guard let scheme = url.scheme, Self.schemes.contains(scheme) else {
            return nil
        }
        guard url.host == Self.host else {
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "pay" else {
            return nil
        }
        
        Logger.general.debug(category: "SafePayment", message: "URL: \(url.absoluteString)")
        let address: Address
        let addressString = pathComponents[2]
        if UUID.isValidLowercasedUUIDString(addressString) {
            address = .user(addressString)
        } else if addressString.hasPrefix("XIN") {
            address = .mainnet(addressString)
        } else if let mixAddress = MIXAddress(string: addressString) {
            address = mixAddress.address
        } else {
            Logger.general.warn(category: "SafePayment", message: "Invalid address: \(addressString)")
            return nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        let queries: [String: String]
        if let items = components.queryItems {
            queries = items.reduce(into: [:], { result, item in
                result[item.name] = item.value
            })
        } else {
            queries = [:]
        }
        
        let asset: String?
        if let id = queries["asset"] {
            if UUID.isValidLowercasedUUIDString(id) {
                asset = id
            } else {
                Logger.general.warn(category: "SafePayment", message: "Invalid asset")
                return nil
            }
        } else {
            asset = nil
        }
        
        let decimalAmount: Decimal?
        if let amount = queries["amount"] {
            if let amount = Decimal(string: amount, locale: .enUSPOSIX), amount > 0, amount.numberOfSignificantFractionalDigits <= 8 {
                decimalAmount = amount
            } else {
                Logger.general.warn(category: "SafePayment", message: "Invalid amount")
                return nil
            }
        } else {
            decimalAmount = nil
        }
        
        let request: Request?
        switch (asset, decimalAmount) {
        case let (.some(asset), .some(decimalAmount)):
            request = Request(asset: asset, amount: decimalAmount)
        case (.none, .none):
            request = nil
        case (.some, .none):
            Logger.general.warn(category: "SafePayment", message: "Invalid args: amount is null")
            return nil
        case (.none, .some):
            Logger.general.warn(category: "SafePayment", message: "Invalid args: asset is null")
            return nil
        }
        
        let trace: String
        if let id = queries["trace"] {
            if UUID.isValidLowercasedUUIDString(id) {
                trace = id
            } else {
                Logger.general.warn(category: "SafePayment", message: "Invalid trace")
                return nil
            }
        } else {
            trace = UUID().uuidString.lowercased()
        }
        
        let redirection: URL?
        if let returnTo = queries["return_to"], let data = returnTo.data(using: .utf8) {
            // Resolve issues when the string contains percent symbol
            // e.g. queries with `#` which has been converted to `%23`
            redirection = URL(dataRepresentation: data, relativeTo: nil)
        } else {
            redirection = nil
        }
        
        self.address = address
        self.request = request
        self.memo = queries["memo"] ?? ""
        self.trace = trace
        self.redirection = redirection
    }
    
}

extension SafePaymentURL {
    
    private struct MIXAddress {
        
        static let header = "MIX"
        static let headerData = header.data(using: .utf8)!
        static let version: UInt8 = 2
        
        let address: Address
        
        init?(string: String) {
            guard string.hasPrefix(Self.header) else {
                return nil
            }
            guard string.count > Self.header.count else {
                Logger.general.debug(category: "MIXAddress", message: "Invalid count: \(string.count)")
                return nil
            }
            
            let base58Encoded = string.suffix(string.count - Self.header.count)
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
            guard let calculatedChecksum = SHA3_256.hash(data: Self.headerData + payload)?.prefix(checksumCount) else {
                Logger.general.debug(category: "MIXAddress", message: "Unable to hash")
                return nil
            }
            guard providedChecksum == calculatedChecksum else {
                Logger.general.debug(category: "MIXAddress", message: "Invalid checksum")
                return nil
            }
            
            let version: UInt8 = payload[0]
            guard version == Self.version else {
                Logger.general.debug(category: "MIXAddress", message: "Unknown version")
                return nil
            }
            
            let threshold: UInt8 = payload[1]
            let membersCount: Int = Int(payload[2])
            guard threshold != 0 && threshold <= membersCount && membersCount <= 64 else {
                Logger.general.debug(category: "MIXAddress", message: "Invalid threshold: \(threshold), total: \(membersCount)")
                return nil
            }
            
            let membersData = payload[3...]
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
                    self.address = .user(userIDs[0])
                } else {
                    self.address = .multisig(threshold: Int32(threshold), userIDs: userIDs.sorted(by: <))
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
                self.address = .mainnet(firstAddress.string())
            default:
                Logger.general.debug(category: "MIXAddress", message: "Invalid members count: \(membersData.count)")
                return nil
            }
        }
        
    }
    
}
