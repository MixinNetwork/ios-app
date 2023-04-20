import Foundation
import MixinServices

struct DeviceTransferApp {
    
    let appId: String
    let appNumber: String
    let redirectUri: String
    let name: String
    let iconUrl: String
    let capabilities: [String]?
    let resourcePatterns: [String]?
    let homeUri: String
    let creatorId: String
    let updatedAt: String?
    let category: String
    
    init(app: App) {
        appId = app.appId
        appNumber = app.appNumber
        redirectUri = app.redirectUri
        name = app.name
        iconUrl = app.iconUrl
        capabilities = app.capabilities
        resourcePatterns = app.resourcePatterns
        homeUri = app.homeUri
        creatorId = app.creatorId
        updatedAt = app.updatedAt
        category = app.category
    }
    
    func toApp() -> App {
        App(appId: appId,
            appNumber: appNumber,
            redirectUri: redirectUri,
            name: name,
            iconUrl: iconUrl,
            capabilities: capabilities,
            resourcePatterns: resourcePatterns,
            homeUri: homeUri,
            creatorId: creatorId,
            updatedAt: updatedAt,
            category: category)
    }
    
}

extension DeviceTransferApp: Codable {
    
    enum CodingKeys: String, CodingKey {
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
    }
    
}
