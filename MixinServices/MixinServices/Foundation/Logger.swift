import Foundation
import Zip

public enum Logger: Equatable {
    
    public static var redirectLogsToLogin = true
    
    case general
    case database
    case call
    case conversation(id: String)
    case tip
    case web3
    case login
    
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
        
        let generalURL = general.fileURL
        if isFileCreated(at: generalURL), !legacyGeneralLog.isEmpty, let handle = FileHandle(forWritingAtPath: generalURL.path) {
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
    
    public static func export(conversationID: String?) -> URL? {
        var subsystems = [general, database, call, tip, web3, login]
        if let conversationID {
            subsystems.append(conversation(id: conversationID))
        }
        var files = subsystems.compactMap(\.fileURL).filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }
        if FileManager.default.fileExists(atPath: AppGroupContainer.webRTCLogURL.path) {
            files.append(AppGroupContainer.webRTCLogURL)
        }
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
        #if DEBUG
        write(level: .debug, category: category, message: message, userInfo: userInfo)
        #endif
    }
    
    public func info(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .info, category: category, message: message, userInfo: userInfo)
    }
    
    public func warn(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .warning, category: category, message: message, userInfo: userInfo)
    }
    
    public func error(category: StaticString, message: String, userInfo: UserInfo? = nil) {
        write(level: .error, category: category, message: message, userInfo: userInfo)
    }
    
    public func debug(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        #if DEBUG
        write(level: .debug, category: category, message: message, userInfo: UserInfo(userInfo))
        #endif
    }
    
    public func info(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .info, category: category, message: message, userInfo: UserInfo(userInfo))
    }
    
    public func warn(category: StaticString, message: String, userInfo: [UserInfo.Key: UserInfo.Value]) {
        write(level: .warning, category: category, message: message, userInfo: UserInfo(userInfo))
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
    
    public var fileURL: URL {
        switch self {
        case .general:
            AppGroupContainer.logUrl.appendingPathComponent("general.log")
        case .database:
            AppGroupContainer.logUrl.appendingPathComponent("database.log")
        case .call:
            AppGroupContainer.logUrl.appendingPathComponent("call.log")
        case .conversation(let id):
            AppGroupContainer.logUrl.appendingPathComponent("\(id).log")
        case .tip:
            AppGroupContainer.logUrl.appendingPathComponent("tip.log")
        case .web3:
            AppGroupContainer.logUrl.appendingPathComponent("wc.log")
        case .login:
            AppGroupContainer.loginLogURL
        }
    }
    
    private enum Level {
        
        case debug
        case info
        case warning
        case error
        
        var briefOutput: String {
            switch self {
            case .debug:
                return "🛠"
            case .info:
                return "ℹ️"
            case .warning:
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
            case .warning:
                return "[WARN] "
            case .error:
                return "[ERROR]"
            }
        }
        
    }
    
    private static let maxFileSize = 2 * bytesPerMegaByte
    private static let preservedTrailingLogSize = 1 * bytesPerMegaByte // Last 1MB of old logs will be preserved when size exceeds maximum
    private static let queue = DispatchQueue(label: "one.mixin.services.log", qos: .utility)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        return formatter
    }()
    
    private static func isFileCreated(at url: URL) -> Bool {
        do {
            try FileManager.default.createFileIfNotExists(at: url)
            return true
        } catch {
            reporter.report(error: error)
            return false
        }
    }
    
    private func write(level: Level, category: StaticString, message: String, userInfo: UserInfo? = nil) {
        let date = Date()
        
        lazy var formattedDate = Self.dateFormatter.string(from: date)
        lazy var formattedUserInfo: String = {
            if let userInfo = userInfo {
                return ", userInfo: {\(userInfo.output)}"
            } else {
                return ""
            }
        }()
        
        #if DEBUG
        let output = "\(formattedDate) \(level.briefOutput)[\(category)] \(message)\(formattedUserInfo)"
        print(output)
        #endif
        
        guard level != .debug else {
            return
        }
        let redirectLogsToLogin = Self.redirectLogsToLogin
        Self.queue.async { [url=fileURL] in
            let appExtensionMark = isAppExtension ? "[AppExtension]" : ""
            let output = "\(formattedDate) \(appExtensionMark)\(level.output)[\(category)] \(message)\(formattedUserInfo)\n"
            if redirectLogsToLogin {
                write(output: output, toFileAt: Logger.login.fileURL)
            } else {
                write(output: output, toFileAt: url)
            }
        }
    }
    
    private func write(output: String, toFileAt url: URL) {
        guard Self.isFileCreated(at: url), let handle = FileHandle(forUpdatingAtPath: url.path) else {
            return
        }
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
