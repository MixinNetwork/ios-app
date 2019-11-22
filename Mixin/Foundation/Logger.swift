import Foundation
import Zip

public enum Logger {
    
    private static let queue = DispatchQueue(label: "one.mixin.messenger.queue.log")
    
    public static func write(log: String, newSection: Bool = false) {
        DispatchQueue.global().async {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: AppGroupContainer.logUrl.path) else {
                return
            }
            for file in files {
                let filename = AppGroupContainer.logUrl.appendingPathComponent(file).lastPathComponent.substring(endChar: ".")
                if log.hasPrefix("No sender key for:") {
                    if log.contains(filename) {
                        Logger.write(conversationId: filename, log: log, newSection: newSection)
                    }
                } else {
                    Logger.write(conversationId: filename, log: log, newSection: newSection)
                }
            }
        }
    }
    
    public static func write(conversationId: String, log: String, newSection: Bool = false) {
        guard AccountAPI.shared.didLogin else {
            return
        }
        guard !conversationId.isEmpty else {
            return
        }
        queue.async {
            var log = log + "...\(DateFormatter.filename.string(from: Date()))\n"
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
                    try lastString?.write(toFile: path, atomically: true, encoding: .utf8)
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
                    try log.write(toFile: path, atomically: true, encoding: .utf8)
                }
            } catch {
                Reporter.report(error: error)
            }
        }
    }
    
    public static func export(conversationId: String) -> URL? {
        let conversationFile = AppGroupContainer.logUrl.appendingPathComponent("\(conversationId).txt")
        let filename = "\(AccountAPI.shared.accountIdentityNumber)_\(DateFormatter.filename.string(from: Date()))"
        do {
            return try Zip.quickZipFiles([conversationFile], fileName: filename)
        } catch {
            #if DEBUG
            print("======FileManagerExtension...exportLog...error:\(error)")
            #endif
        }
        return nil
    }
    
}
