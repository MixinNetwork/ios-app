import Foundation

enum TIPURL {
    
    enum Chain: String {
        case solana
    }
    
    enum Action: String {
        case signRawTransaction
    }
    
    case sign(requestID: String?, chain: Chain, action: Action, raw: String)
    
    init?(url: URL) {
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "tip" else {
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
        
        switch pathComponents[2] {
        case "sign":
            guard
                let chainValue = queries["chain"],
                let chain = Chain(rawValue: chainValue),
                let actionValue = queries["action"],
                let action = Action(rawValue: actionValue),
                let raw = queries["raw"]
            else {
                return nil
            }
            let requestID: String?
            if let id = queries["request_id"] {
                guard UUID.isValidLowercasedUUIDString(id) else {
                    return nil
                }
                requestID = id
            } else {
                requestID = nil
            }
            self = .sign(requestID: requestID, chain: chain, action: action, raw: raw)
        default:
            return nil
        }
    }
    
}
