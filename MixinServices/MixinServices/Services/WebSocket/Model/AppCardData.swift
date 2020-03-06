import Foundation

public struct AppCardData: Codable {

    public let appId: String?
    public let iconUrl: URL
    public let title: String
    public let description: String
    public let action: URL
    public let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case iconUrl = "icon_url"
        case title
        case description
        case action
        case updatedAt = "updated_at"
    }

    public init(appId: String?, iconUrl: URL, title: String, description: String, action: URL, updatedAt: String?) {
        self.appId = appId
        self.iconUrl = iconUrl
        self.title = title
        self.description = description
        self.action = action
        self.updatedAt = updatedAt
    }
    
}
