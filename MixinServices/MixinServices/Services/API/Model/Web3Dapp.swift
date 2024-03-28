import Foundation

public struct Web3Dapp {
    
    public let name: String
    public let homeURL: URL
    public let chains: Set<String>
    public let iconURL: URL
    public let category: String
    
    public var host: String {
        homeURL.host ?? homeURL.absoluteString
    }
    
}

extension Web3Dapp: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case homeURL = "home_url"
        case chains
        case iconURL = "icon_url"
        case category
    }
    
}
