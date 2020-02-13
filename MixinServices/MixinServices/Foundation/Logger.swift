import Foundation
import Zip

public enum Logger {
    
    private static let queue = DispatchQueue(label: "one.mixin.services.queue.log")
    
    public static func write(log: String, newSection: Bool = false) {
        queue.async {
            makeLogDirectoryIfNeeded()
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: AppGroupContainer.logUrl.path) else {
                return
            }
            for file in files {
                let filename = AppGroupContainer.logUrl.appendingPathComponent(file).lastPathComponent.substring(endChar: ".")
                if log.hasPrefix("No sender key for:") {
                    if log.contains(filename) {
                        writeLog(conversationId: filename, log: log, newSection: newSection)
                    }
                } else {
                    writeLog(conversationId: filename, log: log, newSection: newSection)
                }
            }
        }
    }
    
    public static func write(conversationId: String, log: String, newSection: Bool = false) {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        queue.async {
            writeLog(conversationId: conversationId, log: log, newSection: newSection)
        }
    }

    private static func writeLog(conversationId: String, log: String, newSection: Bool = false) {
        makeLogDirectoryIfNeeded()
        var log = "\(isAppExtension ? "[AppExtension]" : "")" + log + "...\(DateFormatter.filename.string(from: Date()))\n"
        if newSection {
            log += "------------------------------\n"
        }
        let url = AppGroupContainer.logUrl.appendingPathComponent("\(conversationId).txt")
        let path = url.path
        do {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.fileSize(path) > 1024 * 1024 * 2 {
                guard let fileHandle = FileHandle(forUpdatingAtPath: path) else {
                    return
                }
                fileHandle.seek(toFileOffset: 1024 * 1024 * 1 + 1024 * 896)
                let lastString = String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8)
                fileHandle.closeFile()
                try FileManager.default.removeItem(at: url)
                try lastString?.write(toFile: path, atomically: false, encoding: .utf8)
            }

            if FileManager.default.fileExists(atPath: path) {
                guard let data = log.data(using: .utf8) else {
                    return
                }
                guard let fileHandle = FileHandle(forUpdatingAtPath: path) else {
                    return
                }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try log.write(toFile: path, atomically: false, encoding: .utf8)
            }
        } catch {
            #if DEBUG
            print("======FileManagerExtension...writeLog...error:\(error)")
            #endif
            reporter.report(error: error)
        }
    }
    
    public static func export(conversationId: String) -> URL? {
        makeLogDirectoryIfNeeded()
        let conversationFile = AppGroupContainer.logUrl.appendingPathComponent("\(conversationId).txt")
        let filename = "\(myIdentityNumber)_\(DateFormatter.filename.string(from: Date()))"
        do {
            return try Zip.quickZipFiles([conversationFile], fileName: filename)
        } catch {
            #if DEBUG
            print("======FileManagerExtension...exportLog...error:\(error)")
            #endif
        }
        return nil
    }
    
    private static func makeLogDirectoryIfNeeded() {
        guard !FileManager.default.fileExists(atPath: AppGroupContainer.logUrl.path) else {
            return
        }
        do {
            try FileManager.default.createDirectory(at: AppGroupContainer.logUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            #if DEBUG
            print("======FileManagerExtension...makeLogDirectoryIfNeeded...error:\(error)")
            #endif
            reporter.report(error: error)
        }
    }
    
}
