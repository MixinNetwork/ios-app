import WCDBSwift

public struct App: BaseCodable {
    
    static var tableName: String = "apps"
    
    public let appId: String
    public let appNumber: String
    public let redirectUri: String
    public let name: String
    public let iconUrl: String
    public var capabilities: [String]?
    public let homeUri: String
    public let creatorId: String
    
    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = App
        case appId = "app_id"
        case appNumber = "app_number"
        case redirectUri = "redirect_uri"
        case name
        case iconUrl = "icon_url"
        case capabilities = "capabilites"
        case homeUri = "home_uri"
        case creatorId = "creator_id"
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                appId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
    
}
