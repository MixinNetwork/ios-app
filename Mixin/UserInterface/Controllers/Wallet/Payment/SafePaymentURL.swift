import Foundation
import MixinServices

struct SafePaymentURL {
    
    enum Request {
        case prefilled(assetID: String, amount: Decimal)
        case inscription(hash: String)
        case notDetermined(assetID: String?, amount: Decimal?)
    }
    
    let address: MIXAddress
    let asset: String?
    let amount: Decimal?
    let memo: String
    let trace: String
    let redirection: URL?
    let reference: String?
    let inscription: String?
    
    var request: Request {
        if let inscription {
            .inscription(hash: inscription)
        } else if let asset, let amount {
            .prefilled(assetID: asset, amount: amount)
        } else {
            .notDetermined(assetID: asset, amount: amount)
        }
    }
    
    init?(url: URL) {
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "pay" else {
            return nil
        }
        
        Logger.general.debug(category: "SafePayment", message: "URL: \(url.absoluteString)")
        let address: MIXAddress
        let addressString = pathComponents[2]
        if UUID.isValidLowercasedUUIDString(addressString) {
            address = .user(addressString)
        } else if addressString.hasPrefix("XIN") {
            address = .mainnet(addressString)
        } else if let mixAddress = MIXAddress(string: addressString) {
            address = mixAddress
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
        
        let inscription: String?
        if let hash = queries["inscription"] {
            if Inscription.isHashValid(hash) {
                inscription = hash
            } else {
                Logger.general.warn(category: "SafePayment", message: "Invalid inscription: \(hash)")
                return nil
            }
        } else {
            inscription = nil
        }
        
        self.address = address
        self.asset = asset
        self.amount = decimalAmount
        self.memo = queries["memo"] ?? ""
        self.trace = trace
        self.redirection = redirection
        self.reference = queries["reference"]
        self.inscription = inscription
    }
    
}
