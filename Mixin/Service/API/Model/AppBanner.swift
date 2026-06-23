import Foundation

struct AppBanner: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case bannerID = "banner_id"
        case iconURL = "icon_url"
        case title = "title"
        case description = "description"
        case actionURL = "action_url"
        case actions = "actions"
        case trackingKey = "tracking_key"
        case chains = "chains"
    }
    
    let bannerID: String
    let iconURL: String
    let title: String
    let description: String
    let actionURL: String?
    let actions: [Action]?
    let trackingKey: String
    let chains: [String]
    
}

extension AppBanner {
    
    struct Action: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case label = "label"
            case action = "action"
        }
        
        let label: String
        let action: String
        
    }
    
}

extension AppBanner: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bannerID == rhs.bannerID
    }
    
}

extension AppBanner: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bannerID)
    }
    
}
