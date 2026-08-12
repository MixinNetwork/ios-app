import Foundation
import MixinServices

struct MixinWebContext {
    
    struct AppEnvironment {
        let app: App
        let user: User?
        let isInitialURLAppHome: Bool
    }
    
    let conversationID: String
    let initialURL: URL
    let isShareable: Bool?
    let saveAsRecentSearch: Bool
    let additionalURLQueries: [String: String]
    
    var appEnvironment: AppEnvironment?
    var isImmersive: Bool
    
    var appContextString: String {
        let ctx: [String: Any] = [
            "app_version": Bundle.main.shortVersionString,
            "immersive": isImmersive,
            "appearance": UserInterfaceStyle.current.rawValue,
            "currency": Currency.current.code,
            "locale": "\(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? "")",
            "platform": "iOS",
            "conversation_id": conversationID
        ]
        if let data = try? JSONSerialization.data(withJSONObject: ctx, options: []), let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            return ""
        }
    }
    
    init(
        conversationID: String,
        initialURL: URL,
        shareable: Bool? = nil,
        saveAsRecentSearch: Bool = false
    ) {
        self.conversationID = conversationID
        self.initialURL = initialURL
        self.isShareable = shareable
        self.saveAsRecentSearch = saveAsRecentSearch
        self.additionalURLQueries = [:]
        self.appEnvironment = nil
        self.isImmersive = false
    }
    
    init(
        conversationID: String,
        app: App,
        url: URL? = nil, // nil to use app.home_uri
        shareable: Bool? = nil,
        additionalURLQueries: [String: String] = [:]
    ) {
        self.conversationID = if conversationID.isEmpty {
            ConversationDAO.shared.makeConversationId(
                userId: myUserId,
                ownerUserId: app.appId
            )
        } else {
            conversationID
        }
        self.initialURL = url ?? URL(string: app.homeUri) ?? .blank
        self.isShareable = shareable
        self.saveAsRecentSearch = false
        self.additionalURLQueries = additionalURLQueries
        self.appEnvironment = AppEnvironment(
            app: app,
            user: nil,
            isInitialURLAppHome: url == nil,
        )
        self.isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
    }
    
}

extension MixinWebContext {
    
    static let applicationNameForUserAgent = "Mixin/\(Bundle.main.shortVersionString)"
    
}
