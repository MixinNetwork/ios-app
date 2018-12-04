import Foundation
import UIKit

class RefreshSnapshotsJob: BaseJob {
    
    enum Category {
        case all
        case opponent(id: String)
        case asset(id: String)
    }
    
    let category: Category
    let limit = 200
    
    init(category: Category) {
        self.category = category
    }
    
    override func getJobId() -> String {
        switch category {
        case .all:
            return "refresh-snapshot"
        case .opponent(let id):
            return "refresh-snapshot-opponent-\(id)"
        case .asset(let id):
            return "refresh-snapshot-asset-\(id)"
        }
    }
    
    override func run() throws {
        let result: APIResult<[Snapshot]>
        switch category {
        case .all:
            result = AssetAPI.shared.snapshots(limit: limit)
        case .opponent(let id):
            result = AssetAPI.shared.snapshots(opponentId: id)
        case .asset(let id):
            result = AssetAPI.shared.snapshots(limit: limit, assetId: id)
        }
        switch result {
        case let .success(snapshots):
            SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: snapshots)
            RefreshSnapshotsJob.setOffset(snapshots.last?.createdAt, for: category)
        case let .failure(error):
            RefreshSnapshotsJob.setOffset(nil, for: category)
            throw error
        }
    }
    
    class func setOffset(_ newValue: String?, for category: Category) {
        switch category {
        case .all:
            WalletUserDefault.shared.allTransactionOffset = newValue
        case .asset(let id):
            WalletUserDefault.shared.assetTransactionOffset[id] = newValue
        case .opponent:
            break
        }
    }
    
    class func offset(for category: Category) -> String? {
        switch category {
        case .all:
            return WalletUserDefault.shared.allTransactionOffset
        case .asset(let id):
            return WalletUserDefault.shared.assetTransactionOffset[id]
        case .opponent:
            return nil
        }
    }
    
}
