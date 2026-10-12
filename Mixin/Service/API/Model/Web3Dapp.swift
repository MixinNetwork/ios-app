import Foundation

final class Web3Dapp: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case name
        case homeURL = "home_url"
        case iconURL = "icon_url"
        case category
    }
    
    let name: String
    let homeURL: URL
    let iconURL: URL
    let category: String
    
    var host: String {
        homeURL.host ?? homeURL.absoluteString
    }
    
    private lazy var lowercasedName = name.lowercased()
    
    func matches(keyword: String) -> Bool {
        let lowercasedKeyword = keyword.lowercased()
        return lowercasedName.contains(lowercasedKeyword)
    }
    
}

extension Web3Dapp: Equatable {
    
    static func == (lhs: Web3Dapp, rhs: Web3Dapp) -> Bool {
        lhs.name == rhs.name
    }
    
}

extension Web3Dapp: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
}
