import Foundation

public struct Web3Dapp {
    
    public let name: String
    public let homeURL: URL
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
        case iconURL = "icon_url"
        case category
    }
    
}
