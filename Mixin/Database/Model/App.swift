import WCDBSwift

struct App: BaseCodable {

    static var tableName: String = "apps"

    let appId: String
    let appNumber: String
    let redirectUri: String
    let name: String
    let iconUrl: String
    var capabilities: [String]?
    let appSecret: String
    let homeUri: String
    let creatorId: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = App
        case appId = "app_id"
        case appNumber = "app_number"
        case redirectUri = "redirect_uri"
        case name
        case iconUrl = "icon_url"
        case capabilities = "capabilites"
        case appSecret = "app_secret"
        case homeUri = "home_uri"
        case creatorId = "creator_id"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                appId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
    }
}
