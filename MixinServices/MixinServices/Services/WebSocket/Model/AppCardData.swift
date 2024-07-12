import Foundation

public enum AppCardData: Codable {
    
    case v0(V0Content)
    case v1(V1Content)
    
    public var appID: String? {
        switch self {
        case .v0(let content):
            content.appId
        case .v1(let content):
            content.appID
        }
    }
    
    public var digest: String {
        switch self {
        case .v0(let content):
            content.title
        case .v1(let content):
            content.title.isEmpty ? content.description : content.title
        }
    }
    
    public var isShareable: Bool? {
        switch self {
        case .v0(let content):
            content.isShareable
        case .v1(let content):
            content.isShareable
        }
    }
    
    var updatedAt: String? {
        switch self {
        case .v0(let content):
            content.updatedAt
        case .v1(let content):
            content.updatedAt
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: V0Content.CodingKeys.self)
        let action = try container.decodeIfPresent(String.self, forKey: V0Content.CodingKeys.action)
        if action.isNilOrEmpty {
            let content = try V1Content(from: decoder)
            self = .v1(content)
        } else {
            let content = try V0Content(from: decoder)
            self = .v0(content)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .v0(let content):
            try content.encode(to: encoder)
        case .v1(let content):
            try content.encode(to: encoder)
        }
    }
    
}

extension AppCardData {
    
    public struct V0Content: Codable {
        
        public let appId: String?
        public let iconUrl: URL
        public let title: String
        public let description: String
        public let action: URL
        public let updatedAt: String?
        public let isShareable: Bool?
        
        enum CodingKeys: String, CodingKey {
            case appId = "app_id"
            case iconUrl = "icon_url"
            case title
            case description
            case action
            case updatedAt = "updated_at"
            case isShareable = "shareable"
        }
        
        public init(appId: String?, iconUrl: URL, title: String, description: String, action: URL, updatedAt: String?, isShareable: Bool?) {
            self.appId = appId
            self.iconUrl = iconUrl
            self.title = title
            self.description = description
            self.action = action
            self.updatedAt = updatedAt
            self.isShareable = isShareable
        }
        
    }
    
    public struct V1Content: Codable {
        
        public struct Action: Codable {
            
            enum CodingKeys: String, CodingKey {
                case action
                case color
                case label
            }
            
            public let action: String
            public let color: String
            public let label: String
            
            public let actionURL: URL?
            public let isActionExternal: Bool
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.action = try container.decode(String.self, forKey: .action)
                self.color = try container.decode(String.self, forKey: .color)
                self.label = try container.decode(String.self, forKey: .label)
                self.actionURL = URL(string: action)
                if let url = actionURL {
                    self.isActionExternal = switch url.scheme {
                    case "mixin":
                        false
                    case "http", "https":
                        url.host != "mixin.one"
                    default:
                        true
                    }
                } else {
                    self.isActionExternal = false
                }
            }
            
        }
        
        public let appID: String
        public let cover: String
        public let title: String
        public let description: String
        public let actions: [Action]
        public let updatedAt: String
        public let isShareable: Bool
        
        public var coverURL: URL? {
            URL(string: cover)
        }
        
        enum CodingKeys: String, CodingKey {
            case appID = "app_id"
            case cover = "cover_url"
            case title
            case description
            case actions
            case updatedAt = "updated_at"
            case isShareable = "shareable"
        }
        
    }
    
}
