import Foundation

public final class Web3Dapp: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case homeURL = "home_url"
        case iconURL = "icon_url"
        case category
    }
    
    public let name: String
    public let homeURL: URL
    public let iconURL: URL
    public let category: String
    
    public var host: String {
        homeURL.host ?? homeURL.absoluteString
    }
    
    private lazy var lowercasedName = name.lowercased()
    
    public func matches(keyword: String) -> Bool {
        let lowercasedKeyword = keyword.lowercased()
        return lowercasedName.contains(lowercasedKeyword)
    }
    
}

extension Web3Dapp: Equatable {
    
    public static func == (lhs: Web3Dapp, rhs: Web3Dapp) -> Bool {
        lhs.name == rhs.name
    }
    
}

extension Web3Dapp: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
}
