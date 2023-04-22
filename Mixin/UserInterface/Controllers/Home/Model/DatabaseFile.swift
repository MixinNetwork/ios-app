import Foundation
import MixinServices
import GRDB

enum DatabaseFile {
    
    case original
    case backup
    case temp
    
    private var name: String {
        switch self {
        case .original:
            return "mixin.db"
        case .backup:
            return "mixin-backup.db"
        case .temp:
            return "mixin-backup-temp.db"
        }
    }
    
    private var db: URL {
        AppGroupContainer.accountUrl.appendingPathComponent("\(name)", isDirectory: false)
    }
    
    private var shm: URL {
        AppGroupContainer.accountUrl.appendingPathComponent("\(name)-shm", isDirectory: false)
    }
    
    private var wal: URL {
        AppGroupContainer.accountUrl.appendingPathComponent("\(name)-wal", isDirectory: false)
    }
    
    static func removeIfExists(_ file: DatabaseFile) throws {
        if FileManager.default.fileExists(atPath: file.db.path) {
            try FileManager.default.removeItem(at: file.db)
        }
        if FileManager.default.fileExists(atPath: file.wal.path) {
            try FileManager.default.removeItem(at: file.wal)
        }
        if FileManager.default.fileExists(atPath: file.shm.path) {
            try FileManager.default.removeItem(at: file.shm)
        }
    }
    
    static func copy(at srcFile: DatabaseFile, to dstFile: DatabaseFile) throws {
        try FileManager.default.copyItem(at: srcFile.db, to: dstFile.db)
    }
    
    static func exists(_ file: DatabaseFile) -> Bool {
        FileManager.default.fileExists(atPath: file.db.path)
    }
    
    static func checkIntegrity(_ file: DatabaseFile) throws {
        let dbQueue = try DatabaseQueue(path: file.db.path)
        try dbQueue.write { db in
            try db.execute(sql: "PRAGMA integrity_check")
        }
    }
    
}

