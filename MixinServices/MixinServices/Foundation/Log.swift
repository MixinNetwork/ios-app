import Foundation

public enum Log {
    
    case general
    case database
    case call
    case conversation(id: String)
    
    public static let maxFileSize = 2 * bytesPerMegaByte
    
    public func debug(category: StaticString? = nil, message: String) {
        write(level: .debug, category: category, message: message)
    }
    
    public func info(category: StaticString? = nil, message: String) {
        write(level: .info, category: category, message: message)
    }
    
    public func error(category: StaticString? = nil, message: String) {
        write(level: .error, category: category, message: message)
    }
    
}

extension Log {
    
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
    
    private func write(level: Level, category: StaticString?, message: String) {
        let date = Date()
        #if DEBUG
        let output: String
        if let category = category {
            output = "\(Self.dateFormatter.string(from: date)) \(level.briefOutput)[\(category)] \(message)"
        } else {
            output = "\(Self.dateFormatter.string(from: date)) \(level.briefOutput)\(message)"
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
                output = "\(Self.dateFormatter.string(from: date)) \(appExtensionMark)\(level.output)[\(category)] \(message)\n"
            } else {
                output = "\(Self.dateFormatter.string(from: date)) \(appExtensionMark)\(level.output)\(message)\n"
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
