import Foundation
import UIKit
import MixinServices

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
        let result: MixinAPI.Result<[SafeSnapshot]>
        switch category {
        case .all:
            result = SafeAPI.snapshots(asset: nil, opponent: nil, offset: nil, limit: limit)
        case .opponent(let id):
            result = SafeAPI.snapshots(asset: nil, opponent: id, offset: nil, limit: limit)
        case .asset(let id):
            result = SafeAPI.snapshots(asset: id, opponent: nil, offset: nil, limit: limit)
        }
        switch result {
        case let .success(snapshots):
            SafeSnapshotDAO.shared.save(snapshots: snapshots)
            RefreshSnapshotsJob.setOffset(snapshots.last?.createdAt, for: category)
        case let .failure(error):
            RefreshSnapshotsJob.setOffset(nil, for: category)
            throw error
        }
    }
    
    class func setOffset(_ newValue: String?, for category: Category) {
        switch category {
        case .all:
            AppGroupUserDefaults.Wallet.allTransactionsOffset = newValue
        case .asset(let id):
            AppGroupUserDefaults.Wallet.assetTransactionsOffset[id] = newValue
        case .opponent(let id):
            AppGroupUserDefaults.Wallet.opponentTransactionsOffset[id] = newValue
        }
    }
    
    class func offset(for category: Category) -> String? {
        switch category {
        case .all:
            return AppGroupUserDefaults.Wallet.allTransactionsOffset
        case .asset(let id):
            return AppGroupUserDefaults.Wallet.assetTransactionsOffset[id]
        case .opponent(let id):
            return AppGroupUserDefaults.Wallet.opponentTransactionsOffset[id]
        }
    }
    
}
