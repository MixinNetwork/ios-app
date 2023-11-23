import Foundation
import MixinServices

struct Payment {
    
    private static let schemes = ["mixin", "https"]
    private static let host = "mixin.one"
    
    enum Address {
        case user(String)
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
    let returnTo: URL?
    
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
        
        let address: Address
        let addressString = pathComponents[2]
        if UUID.isValidLowercasedUUIDString(addressString) {
            address = .user(addressString)
        } else if addressString.hasPrefix("XIN") {
            address = .mainnet(addressString)
        } else {
            Logger.general.warn(category: "Payment", message: "Invalid address: \(addressString)")
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
                Logger.general.warn(category: "Payment", message: "Invalid asset")
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
                Logger.general.warn(category: "Payment", message: "Invalid amount")
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
            Logger.general.warn(category: "Payment", message: "Invalid args: amount is null")
            return nil
        case (.none, .some):
            Logger.general.warn(category: "Payment", message: "Invalid args: asset is null")
            return nil
            
        }
        
        let trace: String
        if let id = queries["trace"] {
            if UUID.isValidLowercasedUUIDString(id) {
                trace = id
            } else {
                Logger.general.warn(category: "Payment", message: "Invalid trace")
                return nil
            }
        } else {
            trace = UUID().uuidString.lowercased()
        }
        
        let returnToURL: URL?
        if let returnTo = queries["return_to"], let data = returnTo.data(using: .utf8) {
            // Resolve issues when the string contains percent symbol
            // e.g. queries with `#` which has been converted to `%23`
            returnToURL = URL(dataRepresentation: data, relativeTo: nil)
        } else {
            returnToURL = nil
        }
        
        self.address = address
        self.request = request
        self.memo = queries["memo"] ?? ""
        self.trace = trace
        self.returnTo = returnToURL
    }
    
}
