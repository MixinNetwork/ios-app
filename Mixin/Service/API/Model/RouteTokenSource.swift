import Foundation

enum RouteTokenSource {
    case mixin
    case web3
    case other(String)
}

extension RouteTokenSource {
    
    init(rawValue: String) {
        switch rawValue {
        case "mixin":
            self = .mixin
        case "web3":
            self = .web3
        default:
            self = .other(rawValue)
        }
    }
    
    var rawValue: String {
        switch self {
        case .mixin:
            "mixin"
        case .web3:
            "web3"
        case .other(let value):
            value
        }
    }
    
}

extension RouteTokenSource: Codable {
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
}
