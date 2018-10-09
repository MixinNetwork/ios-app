import Foundation

class RefreshSnapshotsJob: BaseJob {
    
    enum Key {
        case assetId(String)
        case opponentId(String)
    }
    
    private let key: Key
    
    init(key: Key) {
        self.key = key
    }
    
    override func getJobId() -> String {
        switch key {
        case let .assetId(assetId):
            return "refresh-snapshot-asset-\(assetId)"
        case let .opponentId(opponentId):
            return "refresh-snapshot-opponent-\(opponentId)"
        }
    }
    
    override func run() throws {
        switch key {
        case let .assetId(assetId):
            guard !assetId.isEmpty else {
                return
            }
            switch AssetAPI.shared.snapshots(assetId: assetId) {
            case let .success(snapshots):
                SnapshotDAO.shared.updateSnapshots(snapshots: snapshots)
            case let .failure(error):
                throw error
            }
        case let .opponentId(opponentId):
            guard !opponentId.isEmpty else {
                return
            }
            switch AssetAPI.shared.snapshots(opponentId: opponentId) {
            case let .success(snapshots):
                SnapshotDAO.shared.updateSnapshots(snapshots: snapshots)
            case let .failure(error):
                throw error
            }
        }
    }
    
}
