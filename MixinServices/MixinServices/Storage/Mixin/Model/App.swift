import WCDBSwift

public struct App: BaseCodable {
    
    public static let tableName: String = "apps"
    
    public let appId: String
    public let appNumber: String
    public let redirectUri: String
    public let name: String
    public let iconUrl: String
    public var capabilities: [String]?
    public var resourcePatterns: [String]?
    public let homeUri: String
    public let creatorId: String
    public let updatedAt: String?
    public let category: String
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = App
        case appId = "app_id"
        case appNumber = "app_number"
        case redirectUri = "redirect_uri"
        case name
        case category
        case iconUrl = "icon_url"
        case capabilities = "capabilites"
        case resourcePatterns = "resource_patterns"
        case homeUri = "home_uri"
        case creatorId = "creator_id"
        case updatedAt = "updated_at"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                appId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}

public enum AppCategory: String, Codable {

    case OTHER
    case WALLET
    case TRADING
    case BUSINESS
    case SOCIAL
    case SHOPPING
    case EDUCATION
    case NEWS
    case TOOLS
    case GAMES
    case BOOKS
    case MUSIC
    case PHOTO
    case VIDEO
}
