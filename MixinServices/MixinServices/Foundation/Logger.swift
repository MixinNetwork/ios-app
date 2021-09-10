import Foundation
import Zip

public enum Logger {
    
    case general
    case database
    case call
    case conversation(id: String)
    
    public static func migrate() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: AppGroupContainer.logUrl.path) else {
            return
        }
        guard let contents = try? fileManager.contentsOfDirectory(atPath: AppGroupContainer.logUrl.path) else {
            return
        }
        
        var legacyGeneralLog = Data()
        let legacySystemLogURL = AppGroupContainer.logUrl.appendingPathComponent("system.txt")
        let legacyErrorLogURL = AppGroupContainer.logUrl.appendingPathComponent("error.txt")
        if fileManager.fileExists(atPath: legacySystemLogURL.path), let log = try? Data(contentsOf: legacySystemLogURL) {
            legacyGeneralLog = log
        }
        if fileManager.fileExists(atPath: legacyErrorLogURL.path), let log = try? Data(contentsOf: legacyErrorLogURL) {
            legacyGeneralLog += log
        }
        if let url = general.fileURL, !legacyGeneralLog.isEmpty, let handle = FileHandle(forWritingAtPath: url.path) {
            handle.seekToEndOfFile()
            handle.write(legacyGeneralLog)
            try? fileManager.removeItem(at: legacySystemLogURL)
            try? fileManager.removeItem(at: legacyErrorLogURL)
        }
        
        for filename in contents {
            if filename.hasSuffix(".log") {
                // Do nothing
            } else if filename.hasSuffix(".txt") {
                let newName = String(filename[filename.startIndex..<filename.index(filename.endIndex, offsetBy: -3)]) + "log"
                try? fileManager.moveItem(at: AppGroupContainer.logUrl.appendingPathComponent(filename),
                                          to: AppGroupContainer.logUrl.appendingPathComponent(newName))
            } else {
                let newName = filename + ".log"
                try? fileManager.moveItem(at: AppGroupContainer.logUrl.appendingPathComponent(filename),
                                          to: AppGroupContainer.logUrl.appendingPathComponent(newName))
            }
        }

    }
    
    public static func export(conversationId: String) -> URL? {
        let subsystems = [general, database, call, conversation(id: conversationId)]
        let files = subsystems.compactMap(\.fileURL)
        let filename = "\(myIdentityNumber)_\(DateFormatter.filename.string(from: Date()))"
        do {
            return try Zip.quickZipFiles(files, fileName: filename)
        } catch {
            Logger.general.error(category: "Logger", message: "Failed to zip files: \(error)")
            reporter.report(error: error)
            return nil
        }
    }
    
    public func debug(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .debug, category: category, message: message, userInfo: userInfo)
    }
    
    public func info(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .info, category: category, message: message, userInfo: userInfo)
    }
    
    public func error(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .error, category: category, message: message, userInfo: userInfo)
    }
    
    public func debug(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .debug, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
    public func info(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .info, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
    public func error(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .error, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
}

extension Logger {
    
    public struct UserInfo: ExpressibleByDictionaryLiteral {
        
        public typealias Key = String
        public typealias Value = Any
        
        let elements: [(Key, Value)]
        
        var output: String {
            "\(elements.map({ "\($0): \($1)" }).joined(separator: ", "))"
        }
        
        public init(dictionaryLiteral elements: (Key, Value)...) {
            self.elements = elements
        }
        
        public init(_ dictionary: [Key: Value]) {
            self.elements = dictionary.map({ $0 })
        }
        
    }
    
    private enum Level {
        
        case debug
        case info
        case warn
        case error
        
        var briefOutput: String {
            switch self {
            case .debug:
                return "🛠"
            case .info:
                return "ℹ️"
            case .warn:
                return "⚠️"
            case .error:
                return "❌"
            }
        }
        
        var output: String {
            switch self {
            case .debug:
                return "[DEBUG]"
            case .info:
                return "[INFO] "
            case .warn:
                return "[WARN] "
            case .error:
                return "[ERROR]"
            }
        }
        
    }
    
    private static let maxFileSize = 5 * bytesPerMegaByte
    private static let preservedTrailingLogSize = 1 * bytesPerMegaByte // Last 1MB of old logs will be preserved when size exceeds maximum
    private static let queue = DispatchQueue(label: "one.mixin.services.log", qos: .utility)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZ"
        return formatter
    }()
    
    private var fileURL: URL? {
        let filename: String
        switch self {
        case .general:
            filename = "general.log"
        case .database:
            filename = "database.log"
        case .call:
            filename = "call.log"
        case .conversation(let id):
            filename = "\(id).log"
        }
        let url = AppGroupContainer.logUrl.appendingPathComponent(filename)
        do {
            try FileManager.default.createFileIfNotExists(at: url)
            return url
        } catch {
            reporter.report(error: error)
            return nil
        }
    }
    
    private func write(level: Level, category: StaticString, message: String, userInfo: UserInfo? = nil) {
        let date = Date()
        
        var formattedDate: String {
            // Formatting a date may reduce the performance of caller, use a computed
            // var to postpone this procedure to background queue
            Self.dateFormatter.string(from: date)
        }
        
        var formattedUserInfo: String {
            if let userInfo = userInfo {
                return ", userInfo: {\(userInfo.output)}"
            } else {
                return ""
            }
        }
        
        #if DEBUG
        let output = "\(formattedDate) \(level.briefOutput)[\(category)] \(message)\(formattedUserInfo)"
        print(output)
        #endif
        
        guard level != .debug else {
            return
        }
        Self.queue.async {
            guard let url = self.fileURL, let handle = FileHandle(forUpdatingAtPath: url.path) else {
                return
            }
            
            let appExtensionMark = isAppExtension ? "[AppExtension]" : ""
            let output = "\(formattedDate) \(appExtensionMark)\(level.output)[\(category)] \(message)\(formattedUserInfo)\n"
            
            let existedFileSize = FileManager.default.fileSize(url.path)
            if existedFileSize > Self.maxFileSize {
                let trailingOffset = UInt64(existedFileSize) - UInt64(Self.preservedTrailingLogSize)
                handle.seek(toFileOffset: trailingOffset)
                let trailing = String(data: handle.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if let data = (trailing + "\n" + output).data(using: .utf8) {
                    try? data.write(to: url)
                }
            } else {
                if let data = output.data(using: .utf8) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                }
            }
        }
    }
    
}
