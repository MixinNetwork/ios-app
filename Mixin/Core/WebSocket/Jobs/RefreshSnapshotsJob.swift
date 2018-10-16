import Foundation
import UIKit

class RefreshSnapshotsJob: BaseJob {
    
    enum Key {
        case asset(id: String, key: String?) // key is public key of asset, or account_tag for EOS
        case opponentId(String)
    }
    
    private let key: Key
    
    init(key: Key) {
        self.key = key
    }
    
    override func getJobId() -> String {
        switch key {
        case let .asset(id, _):
            return "refresh-snapshot-asset-\(id)"
        case let .opponentId(opponentId):
            return "refresh-snapshot-opponent-\(opponentId)"
        }
    }
    
    override func run() throws {
        switch key {
        case let .asset(id, key):
            if let key = key {
                switch AssetAPI.shared.pendingDeposits(key: key, assetId: id) {
                case let .success(deposits):
                    SnapshotDAO.shared.replacePendingDeposits(assetId: id, pendingDeposits: deposits)
                case let .failure(error):
                    UIApplication.trackError(getJobId(), action: "Get pending deposits", userInfo: ["error": error])
                }
            }
            switch AssetAPI.shared.snapshots(assetId: id) {
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
