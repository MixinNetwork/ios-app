import Foundation
import MixinServices

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
    
    var db: URL {
        AppGroupContainer.accountUrl.appendingPathComponent("\(name)", isDirectory: false)
    }
    
    var shm: URL {
        AppGroupContainer.accountUrl.appendingPathComponent("\(name)-shm", isDirectory: false)
    }
    
    var wal: URL {
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
    
    static func copy(at srcFile: DatabaseFile, to dstFIle: DatabaseFile) throws {
        try removeIfExists(dstFIle)
        try FileManager.default.copyItem(at: srcFile.db, to: dstFIle.db)
        try FileManager.default.copyItem(at: srcFile.wal, to: dstFIle.wal)
        try FileManager.default.copyItem(at: srcFile.shm, to: dstFIle.shm)
    }
    
    static func exists(_ file: DatabaseFile) -> Bool {
        FileManager.default.fileExists(atPath: file.db.path) &&
        FileManager.default.fileExists(atPath: file.wal.path) &&
        FileManager.default.fileExists(atPath: file.shm.path)
    }
    
}

