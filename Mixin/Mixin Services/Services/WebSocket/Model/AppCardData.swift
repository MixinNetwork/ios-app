import Foundation

struct AppCardData: Codable {
    
    let iconUrl: URL
    let title: String
    let description: String
    let action: URL

    enum CodingKeys: String, CodingKey {
        case iconUrl = "icon_url"
        case title
        case description
        case action
    }
}
