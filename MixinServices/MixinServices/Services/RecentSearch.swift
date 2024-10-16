import Foundation

public enum RecentSearch: InstanceInitializable {
    case market(coinID: String)
    case app(userID: String)
}

extension RecentSearch: RawRepresentable {
    
    private static let maxLinkTitleCount = 50
    
    public init?(rawValue: Data) {
        guard !rawValue.isEmpty else {
            return nil
        }
        var data = rawValue
        let id = data.removeFirst()
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        switch id {
        case 0:
            self = .market(coinID: string)
        case 1:
            self = .app(userID: string)
        default:
            return nil
        }
    }
    
    public var rawValue: Data {
        switch self {
        case let .market(coinID):
            [0x00] + (coinID.data(using: .utf8) ?? Data())
        case let .app(userID):
            [0x01] + (userID.data(using: .utf8) ?? Data())
        }
    }
    
}
