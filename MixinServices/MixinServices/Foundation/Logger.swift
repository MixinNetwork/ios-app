import Foundation
import Zip

public enum Logger {
    
    case general
    case database
    case call
    case conversation(id: String)
    
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
    
    public func debug(category: StaticString? = nil, message: String, userInfo: UserInfo? = nil) {
        write(level: .debug, category: category, message: message, userInfo: userInfo)
    }
    
    public func info(category: StaticString? = nil, message: String, userInfo: UserInfo? = nil) {
        write(level: .info, category: category, message: message, userInfo: userInfo)
    }
    
    public func error(category: StaticString? = nil, message: String, userInfo: UserInfo? = nil) {
        write(level: .error, category: category, message: message, userInfo: userInfo)
    }
    
    public func debug(category: StaticString? = nil, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .debug, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
    public func info(category: StaticString? = nil, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .info, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
    public func error(category: StaticString? = nil, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
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
                return "[INFO]"
            case .warn:
                return "[WARN]"
            case .error:
                return "[ERROR]"
            }
        }
        
    }
    
    private static let maxFileSize = 5 * bytesPerMegaByte
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
            filename = "db.log"
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
    
    private func write(level: Level, category: StaticString?, message: String, userInfo: UserInfo? = nil) {
        let date = Date()
        
        var formattedDate: String {
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
        let output: String
        if let category = category {
            output = "\(formattedDate) \(level.briefOutput)[\(category)] \(message)\(formattedUserInfo)"
        } else {
            output = "\(formattedDate) \(level.briefOutput)\(message)\(formattedUserInfo)"
        }
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
            let output: String
            if let category = category {
                output = "\(formattedDate) \(appExtensionMark)\(level.output)[\(category)] \(message)\(formattedUserInfo)\n"
            } else {
                output = "\(formattedDate) \(appExtensionMark)\(level.output)\(message)\(formattedUserInfo)\n"
            }
            
            let existedFileSize = FileManager.default.fileSize(url.path)
            if existedFileSize > Self.maxFileSize {
                handle.seek(toFileOffset: UInt64(existedFileSize) - 128)
                let trailing = String(data: handle.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if let data = (trailing + "\n" + output).data(using: .utf8) {
                    handle.seek(toFileOffset: 0)
                    handle.write(data)
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
