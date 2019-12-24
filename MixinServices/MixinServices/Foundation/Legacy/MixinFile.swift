import Foundation

internal struct MixinFile {
    
    enum ChatDirectory: String {
        case photos = "Photos"
        case files = "Files"
        case videos = "Videos"
        case audios = "Audios"
        
        var messageCategorySuffix: String {
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

        static func getDirectory(category: String) -> ChatDirectory? {
            if category.hasSuffix("_IMAGE") {
                return .photos
            } else if category.hasSuffix("_DATA") {
                return .files
            } else if category.hasSuffix("_AUDIO") {
                return .audios
            } else if category.hasSuffix("_VIDEO") {
                return .videos
            } else {
                return nil
            }
        }
    }

    static var iCloudBackupDirectory: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent(myIdentityNumber).appendingPathComponent("Backup")
    }

    static var rootDirectory: URL {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(myIdentityNumber)
        _ = FileManager.default.createNobackupDirectory(dir)
        return dir
    }

    static var logPath: URL {
        let url = rootDirectory.appendingPathComponent("Log")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    static var databaseURL: URL {
        return rootDirectory.appendingPathComponent("mixin.db")
    }

    static var taskDatabaseURL: URL {
        return rootDirectory.appendingPathComponent("task.db")
    }

    static var signalDatabasePath: String {
        let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return dir.appendingPathComponent("signal.db").path
    }

    static let backupDatabaseName = "mixin.db"

    static func url(ofChatDirectory directory: ChatDirectory, filename: String?) -> URL {
        let url = rootDirectory.appendingPathComponent("Chat").appendingPathComponent(directory.rawValue)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        if let filename = filename {
            return url.appendingPathComponent(filename)
        } else {
            return url
        }
    }

    static func url(ofChatDirectory directory: ChatDirectory, messageId: String, fileExtension: String) -> URL {
        let url = rootDirectory.appendingPathComponent("Chat").appendingPathComponent(directory.rawValue)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url.appendingPathComponent("\(messageId).\(fileExtension)")
    }
    
    static func clean(chatDirectory: ChatDirectory) {
        let resourcePath = url(ofChatDirectory: chatDirectory, filename: nil).path
        guard let onDiskFilenames = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) else {
            return
        }
        if chatDirectory == .videos {
            let referencedFilenames = MessageDAO.shared
                .getMediaUrls(likeCategory: chatDirectory.messageCategorySuffix)
                .map({ NSString(string: $0).deletingPathExtension })
            for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(where: { onDiskFilename.contains($0) }) {
                let path = MixinFile.url(ofChatDirectory: .videos, filename: onDiskFilename)
                try? FileManager.default.removeItem(at: path)
            }
        } else {
            let referencedFilenames = Set(MessageDAO.shared.getMediaUrls(likeCategory: chatDirectory.messageCategorySuffix))
            for onDiskFilename in onDiskFilenames where !referencedFilenames.contains(onDiskFilename) {
                let path = MixinFile.url(ofChatDirectory: chatDirectory, filename: onDiskFilename)
                try? FileManager.default.removeItem(at: path)
            }
        }
    }
    
    static func cleanAllChatDirectories() {
        let dirs: [ChatDirectory] = [.photos, .audios, .files, .videos]
        dirs.forEach(clean)
    }
    
    static var groupIconsUrl: URL {
        let url = rootDirectory.appendingPathComponent("Group").appendingPathComponent("Icons")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

}
