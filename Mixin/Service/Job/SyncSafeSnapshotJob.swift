import Foundation
import MixinServices

final class SyncSafeSnapshotJob: BaseJob {
    
    private let limit = 300
    
    override func getJobId() -> String {
        "sync-snapshot"
    }
    
    override func run() throws {
        let initialOffset: String? = PropertiesDAO.shared.value(forKey: .snapshotOffset)
        Logger.general.debug(category: "SyncSafeSnapshot", message: "Sync from initial offset: \(initialOffset ?? "(null)")")
        var result = SafeAPI.snapshots(offset: initialOffset, limit: limit)
        while true {
            let snapshots = try result.get()
            let offset = snapshots.last?.createdAt
            Logger.general.debug(category: "SyncSafeSnapshot", message: "Write \(snapshots.count) snapshots, new offset: \(offset ?? "(null)")")
            SafeSnapshotDAO.shared.save(snapshots: snapshots) { db in
                if let offset {
                    try PropertiesDAO.shared.set(offset, forKey: .snapshotOffset, db: db)
                }
            }
            if snapshots.count < limit {
                Logger.general.debug(category: "SyncSafeSnapshot", message: "Sync finished")
                break
            } else {
                Logger.general.debug(category: "SyncSafeSnapshot", message: "Sync from initial offset: \(offset ?? "(null)")")
                result = SafeAPI.snapshots(offset: offset, limit: limit)
            }
        }
    }
    
}
