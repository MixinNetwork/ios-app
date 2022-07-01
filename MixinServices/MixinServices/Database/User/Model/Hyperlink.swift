import Foundation
import GRDB

public struct Hyperlink {
    
    public let link: String
    public let siteName: String
    public let siteTitle: String
    public let siteDescription: String?
    public let siteImage: String?
    
    public init(link: String) {
        self.link = link
        self.siteName = ""
        self.siteTitle = ""
        self.siteDescription = nil
        self.siteImage = nil
    }
    
}

extension Hyperlink: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case link = "hyperlink"
        case siteName = "site_name"
        case siteTitle = "site_title"
        case siteDescription = "site_description"
        case siteImage = "site_image"
    }
    
}

extension Hyperlink: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "hyperlinks"
    
}
