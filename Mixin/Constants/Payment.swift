import Foundation

struct Payment {
    
    private static let schemes = ["mixin", "https"]
    private static let host = "mixin.one"
    
    enum Address {
        case user(String)
    }
    
    let address: Address
    let asset: String?
    let amount: Decimal?
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
                return nil
            }
        } else {
            trace = UUID().uuidString.lowercased()
        }
        
        let returnToURL: URL?
        if let returnTo = queries["return_to"] {
            returnToURL = URL(string: returnTo)
        } else {
            returnToURL = nil
        }
        
        let addressString = pathComponents[2]
        if UUID.isValidLowercasedUUIDString(addressString) {
            self.address = .user(addressString)
        } else {
            return nil
        }
        
        self.asset = asset
        self.amount = decimalAmount
        self.memo = queries["memo"] ?? ""
        self.trace = trace
        self.returnTo = returnToURL
    }
    
}
