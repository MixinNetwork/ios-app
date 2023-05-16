import Foundation

public enum AttachmentContainer {
    
    public static var url: URL {
        let url = AppGroupContainer.accountUrl.appendingPathComponent("Chat", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        return url
    }
    
    public static func url(for category: Category, filename: String?) -> URL {
        let url = Self.url.appendingPathComponent(category.pathComponent)
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        if let filename = filename {
            assert(!filename.isEmpty)
            return url.appendingPathComponent(filename)
        } else {
            return url
        }
    }
    
    public static func videoThumbnailURL(videoFilename: String) -> URL {
        let filename: String
        if let dotIndex = videoFilename.lastIndex(of: ".") {
            filename = String(videoFilename[videoFilename.startIndex..<dotIndex])
        } else {
            filename = videoFilename
        }
        return url(for: .videos, filename: filename + ExtensionName.jpeg.withDot)
    }
    
    public static func url(transcriptId: String, filename: String?) -> URL {
        let url = Self.url.appendingPathComponent("Transcript", isDirectory: true)
            .appendingPathComponent(transcriptId, isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        if let filename = filename {
            assert(!filename.isEmpty)
            return url.appendingPathComponent(filename)
        } else {
            return url
        }
    }
    
    public static func videoThumbnailURL(transcriptId: String, videoFilename: String) -> URL {
        let filename: String
        if let dotIndex = videoFilename.lastIndex(of: ".") {
            filename = String(videoFilename[videoFilename.startIndex..<dotIndex])
        } else {
            filename = videoFilename
        }
        return url(transcriptId: transcriptId, filename: filename + ExtensionName.jpeg.withDot)
    }
    
    public static func wallpaperURL(for key: String) -> URL {
        let url = Self.url.appendingPathComponent("Wallpaper")
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        return url.appendingPathComponent(key)
    }

    public static func deviceTransferURL() -> URL {
        let url = AppGroupContainer.accountUrl.appendingPathComponent("DeviceTransfer", isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        return url
    }
    
    public static func deviceTransferDataURL(isFile: Bool, fileName: String?) -> URL {
        let type = isFile ? "File" : "Message"
        let url = Self.deviceTransferURL().appendingPathComponent(type, isDirectory: true)
        try? FileManager.default.createDirectoryIfNotExists(at: url)
        if let fileName {
            assert(!fileName.isEmpty)
            return url.appendingPathComponent("\(fileName).bin")
        } else {
            return url
        }
    }
    
    public static func removeMediaFiles(mediaUrl: String, category: String) {
        guard let category = AttachmentContainer.Category(messageCategory: category) else {
            return
        }
        guard !mediaUrl.isEmpty else {
            return
        }
        let url = AttachmentContainer.url(for: category, filename: mediaUrl)
        try? FileManager.default.removeItem(at: url)
        if category == .videos {
            let thumbUrl = AttachmentContainer.videoThumbnailURL(videoFilename: mediaUrl)
            try? FileManager.default.removeItem(at: thumbUrl)
        }
    }
    
    public static func removeAll(transcriptId: String) {
        let url = Self.url(transcriptId: transcriptId, filename: nil)
        try? FileManager.default.removeItem(at: url)
    }
    
}

public extension AttachmentContainer {
    
    enum Category: CaseIterable {
        
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
                return [.SIGNAL_IMAGE, .PLAIN_IMAGE, .ENCRYPTED_IMAGE]
            case .files:
                return [.SIGNAL_DATA, .PLAIN_DATA, .ENCRYPTED_DATA]
            case .videos:
                return [.SIGNAL_VIDEO, .PLAIN_VIDEO, .ENCRYPTED_VIDEO]
            case .audios:
                return [.SIGNAL_AUDIO, .PLAIN_AUDIO, .ENCRYPTED_AUDIO]
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
