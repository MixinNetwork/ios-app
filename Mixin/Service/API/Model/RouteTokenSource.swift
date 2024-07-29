import Foundation

enum RouteTokenSource {
    case exin
    case other(String)
}

extension RouteTokenSource {
    
    init(rawValue: String) {
        switch rawValue {
        case "exin":
            self = .exin
        default:
            self = .other(rawValue)
        }
    }
    
    var rawValue: String {
        switch self {
        case .exin:
            "exin"
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
