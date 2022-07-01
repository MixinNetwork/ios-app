import Foundation
import GRDB

public struct HyperlinkItem {
    
    public let link: String
    public let siteName: String
    public let siteTitle: String
    public let siteDescription: String?
    public let siteImage: String?
    public let createdAt: String
    
}

extension HyperlinkItem: Codable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case link = "hyperlink"
        case siteName = "site_name"
        case siteTitle = "site_title"
        case siteDescription = "site_description"
        case siteImage = "site_image"
        case createdAt = "created_at"
    }
    
}
