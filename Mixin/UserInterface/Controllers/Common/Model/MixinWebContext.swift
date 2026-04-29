import Foundation
import MixinServices

struct MixinWebContext {
    
    enum Style {
        case webPage
        case app(app: App, isHomeUrl: Bool)
    }
    
    let conversationId: String
    let initialUrl: URL
    let isShareable: Bool?
    let saveAsRecentSearch: Bool
    
    var style: Style
    var isImmersive: Bool
    var extraParams: [String: String] = [:]
    
    var appContextString: String {
        let ctx: [String: Any] = [
            "app_version": Bundle.main.shortVersionString,
            "immersive": isImmersive,
            "appearance": UserInterfaceStyle.current.rawValue,
            "currency": Currency.current.code,
            "locale": "\(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? "")",
            "platform": "iOS",
            "conversation_id": conversationId
        ]
        if let data = try? JSONSerialization.data(withJSONObject: ctx, options: []), let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            return ""
        }
    }
    
    init(conversationId: String, app: App, shareable: Bool? = nil, extraParams: [String: String] = [:]) {
        if conversationId.isEmpty {
            self.conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: app.appId)
        } else {
            self.conversationId = conversationId
        }
        self.initialUrl = URL(string: app.homeUri) ?? .blank
        self.isShareable = shareable
        self.saveAsRecentSearch = false
        self.style = .app(app: app, isHomeUrl: true)
        self.isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
        self.extraParams = extraParams
    }
    
    init(conversationId: String, initialUrl: URL, shareable: Bool? = nil, saveAsRecentSearch: Bool = false) {
        self.conversationId = conversationId
        self.initialUrl = initialUrl
        self.isShareable = shareable
        self.saveAsRecentSearch = saveAsRecentSearch
        self.style = .webPage
        self.isImmersive = false
    }
    
    init(conversationId: String, url: URL, app: App, shareable: Bool? = nil) {
        self.conversationId = conversationId
        self.initialUrl = url
        self.isShareable = shareable
        self.saveAsRecentSearch = false
        self.style = .app(app: app, isHomeUrl: false)
        self.isImmersive = app.capabilities?.contains("IMMERSIVE") ?? false
    }
    
}

extension MixinWebContext {
    
    static let applicationNameForUserAgent = "Mixin/\(Bundle.main.shortVersionString)"
    
}
