import WCDBSwift

public struct App: BaseCodable {
    
    public static let tableName: String = "apps"
    public static let walletAppId = "1462e610-7de1-4865-bc06-d71cfcbd0329"
    public static let scanAppId = "1cc9189a-ddcd-4b95-a18b-4411da1b8d80"
    public static let cameraAppId = "15366a81-077c-414b-8829-552c5c87a2ae"
    
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
