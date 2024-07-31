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
            if content.title.isNilOrEmpty {
                content.description ?? ""
            } else {
                content.title ?? ""
            }
        }
    }
    
    public var isShareable: Bool? {
        switch self {
        case .v0(let content):
            content.isShareable
        case .v1(let content):
            if content.isShareable {
                content.actions.allSatisfy { action in
                    // Forbid forwarding card with action of "input:"
                    if let url = action.actionURL {
                        ["mixin", "http", "https"].contains(url.scheme)
                    } else {
                        false
                    }
                }
            } else {
                false
            }
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
        let action = try container.decodeIfPresent(String.self, forKey: .action)
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
        
        public enum Cover: Codable {
            
            case plain(String)
            case rich(RichCover)
            
            public var ratio: CGFloat {
                switch self {
                case .plain:
                    1
                case .rich(let cover):
                    cover.ratio
                }
            }
            
            public func thumbnail() -> UIImage? {
                switch self {
                case .plain:
                    nil
                case .rich(let cover):
                    if let blurhash = cover.thumbnail {
                        UIImage(blurHash: blurhash, size: .blurHashThumbnail)
                    } else {
                        nil
                    }
                }
            }
            
        }
        
        public struct RichCover: Codable {
            
            enum CodingKeys: String, CodingKey {
                case url
                case width
                case height
                case thumbnail
            }
            
            public let url: URL?
            public let width: Int
            public let height: Int
            public let thumbnail: String?
            public let ratio: CGFloat
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let urlString = try container.decode(String.self, forKey: .url)
                let width = try container.decode(Int.self, forKey: .width)
                let height = try container.decode(Int.self, forKey: .height)
                self.url = URL(string: urlString)
                self.width = width
                self.height = height
                self.thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
                self.ratio = CGFloat(width) / CGFloat(height)
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(url, forKey: .url)
                try container.encode(width, forKey: .width)
                try container.encode(height, forKey: .height)
                try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
            }
            
        }
        
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
        public let cover: Cover?
        public let title: String?
        public let description: String?
        public let actions: [Action]
        public let updatedAt: String
        public let isShareable: Bool
        
        enum CodingKeys: String, CodingKey {
            case appID = "app_id"
            case cover = "cover"
            case coverURL = "cover_url"
            case title
            case description
            case actions
            case updatedAt = "updated_at"
            case shareable = "shareable"
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.appID = try container.decode(String.self, forKey: .appID)
            if let cover = try container.decodeIfPresent(RichCover.self, forKey: .cover), cover.url != nil {
                self.cover = .rich(cover)
            } else if let string = try container.decodeIfPresent(String.self, forKey: .coverURL), !string.isEmpty {
                self.cover = .plain(string)
            } else {
                self.cover = nil
            }
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            self.actions = try container.decode([Action].self, forKey: .actions)
            self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
            self.isShareable = try container.decode(Bool.self, forKey: .shareable)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(appID, forKey: .appID)
            switch cover {
            case .plain(let string):
                try container.encode(string, forKey: .coverURL)
            case .rich(let cover):
                try container.encode(cover, forKey: .cover)
            case .none:
                break
            }
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(actions, forKey: .actions)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(isShareable, forKey: .shareable)
        }
        
    }
    
}
