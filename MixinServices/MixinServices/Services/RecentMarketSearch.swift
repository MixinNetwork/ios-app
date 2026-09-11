import Foundation

public enum RecentMarketSearch: InstanceInitializable, Codable, Equatable {
    case crypto(coinID: String)
    case perps(marketID: String)
}

extension RecentMarketSearch: RawRepresentable {
    
    public init?(rawValue: Data) {
        if let object = try? JSONDecoder.default.decode(RecentMarketSearch.self, from: rawValue) {
            self.init(instance: object)
        } else {
            return nil
        }
    }
    
    public var rawValue: Data {
        if let data = try? JSONEncoder.default.encode(self) {
            return data
        } else {
            return Data()
        }
    }
    
}
