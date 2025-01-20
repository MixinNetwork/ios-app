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
                    UIImage(blurHash: cover.thumbnail, size: .blurHashThumbnail)
                }
            }
            
        }
        
        public struct RichCover: Codable {
            
            enum CodingKeys: String, CodingKey {
                case url
                case mimeType = "mime_type"
                case width
                case height
                case thumbnail
            }
            
            public let url: URL?
            public let mimeType: String
            public let width: Int
            public let height: Int
            public let thumbnail: String
            public let ratio: CGFloat
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let urlString = try container.decode(String.self, forKey: .url)
                let width = try container.decode(Int.self, forKey: .width)
                let height = try container.decode(Int.self, forKey: .height)
                self.url = URL(string: urlString)
                self.mimeType = try container.decode(String.self, forKey: .mimeType)
                self.width = width
                self.height = height
                self.thumbnail = try container.decode(String.self, forKey: .thumbnail)
                self.ratio = CGFloat(width) / CGFloat(height)
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(url, forKey: .url)
                try container.encode(mimeType, forKey: .mimeType)
                try container.encode(width, forKey: .width)
                try container.encode(height, forKey: .height)
                try container.encode(thumbnail, forKey: .thumbnail)
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
                self.isActionExternal = Self.isActionExternal(url: actionURL)
            }
            
            public init(action: String, color: String, label: String) {
                self.action = action
                self.color = color
                self.label = label
                self.actionURL = URL(string: action)
                self.isActionExternal = Self.isActionExternal(url: actionURL)
            }
            
            private static func isActionExternal(url: URL?) -> Bool {
                if let url {
                    switch url.scheme {
                    case "mixin":
                        false
                    case "http", "https":
                        url.host != "mixin.one"
                    default:
                        true
                    }
                } else {
                    false
                }
            }
            
        }
        
        public let appID: String
        public let cover: Cover?
        public let title: String?
        public let description: String?
        public let actions: [Action]
        public let updatedAt: String?
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
        
        public init(
            appID: String, cover: Cover?, title: String?, description: String?,
            actions: [Action], updatedAt: String?, isShareable: Bool
        ) {
            self.appID = appID
            self.cover = cover
            self.title = title
            self.description = description
            self.actions = actions
            self.updatedAt = updatedAt
            self.isShareable = isShareable
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
            self.actions = try container.decodeIfPresent([Action].self, forKey: .actions) ?? []
            self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
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
            if !actions.isEmpty {
                try container.encode(actions, forKey: .actions)
            }
            if let updatedAt {
                try container.encode(updatedAt, forKey: .updatedAt)
            }
            try container.encode(isShareable, forKey: .shareable)
        }
        
    }
    
}
