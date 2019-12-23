import Foundation

public struct AppCardData: Codable {
    
    public let iconUrl: URL
    public let title: String
    public let description: String
    public let action: URL
    
    enum CodingKeys: String, CodingKey {
        case iconUrl = "icon_url"
        case title
        case description
        case action
    }
    
}
