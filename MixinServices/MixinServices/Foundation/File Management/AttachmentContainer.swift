import Foundation

public enum AttachmentContainer {
    
    public static var url: URL {
        let url = AppGroupContainer.accountUrl.appendingPathComponent("Chat", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        return url
    }
    
    public static func url(for category: Category, filename: String?) -> URL {
        let url = Self.url.appendingPathComponent(category.pathComponent)
        try? FileManager.default.createDirectoryIfNotExists(atPath: url.path)
        if let filename = filename {
            return url.appendingPathComponent(filename)
        } else {
            return url
        }
    }
    
    public static func cleanUp(conversationId: String, categories: [Category]) {
        ConcurrentJobQueue.shared.addJob(job: AttachmentCleanUpJob(conversationId: conversationId, categories: categories))
    }
    
    public static func cleanUp(category: Category) {
        let path = url(for: category, filename: nil).path
        guard let onDiskFilenames = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return
        }
        if category == .videos {
            let referencedFilenames = MessageDAO.shared
                .getMediaUrls(likeCategory: category.messageCategorySuffix)
                .map({ NSString(string: $0).deletingPathExtension })
            for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(where: { onDiskFilename.contains($0) }) {
                let url = Self.url(for: .videos, filename: onDiskFilename)
                try? FileManager.default.removeItem(at: url)
            }
        } else {
            let referencedFilenames = Set(MessageDAO.shared.getMediaUrls(likeCategory: category.messageCategorySuffix))
            for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(onDiskFilename) {
                let url = Self.url(for: category, filename: onDiskFilename)
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    public static func cleanUpAll() {
        [.photos, .audios, .files, .videos].forEach(cleanUp)
    }
    
}

public extension AttachmentContainer {
    
    enum Category {
        
        case audios
        case files
        case photos
        case videos
        
        public var pathComponent: String {
            switch self {
            case .audios:
                return "Audios"
            case .files:
                return "Files"
            case .photos:
                return "Photos"
            case .videos:
                return "Videos"
            }
        }
        
        public var messageCategorySuffix: String {
            switch self {
            case .photos:
                return "_IMAGE"
            case .files:
                return "_DATA"
            case .videos:
                return "_VIDEO"
            case .audios:
                return "_AUDIO"
            }
        }
        
        public var messageCategory: [MessageCategory] {
            switch self {
            case .photos:
                return [.SIGNAL_IMAGE, .PLAIN_IMAGE]
            case .files:
                return [.SIGNAL_DATA, .PLAIN_DATA]
            case .videos:
                return [.SIGNAL_VIDEO, .PLAIN_VIDEO]
            case .audios:
                return [.SIGNAL_AUDIO, .PLAIN_AUDIO]
            }
        }
        
        public init?(messageCategory: String) {
            if messageCategory.hasSuffix("_IMAGE") {
                self = .photos
            } else if messageCategory.hasSuffix("_DATA") {
                self = .files
            } else if messageCategory.hasSuffix("_AUDIO") {
                self = .audios
            } else if messageCategory.hasSuffix("_VIDEO") {
                self = .videos
            } else {
                return nil
            }
        }
        
    }
    
}
