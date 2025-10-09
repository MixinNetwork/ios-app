import Foundation

public enum RecentSearch: InstanceInitializable, Codable {
    case mixinToken(assetID: String)
    case app(userID: String)
    case link(title: String, url: URL)
    case dapp(name: String)
}

extension RecentSearch: RawRepresentable {
    
    public init?(rawValue: Data) {
        if let object = try? JSONDecoder.default.decode(RecentSearch.self, from: rawValue) {
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
