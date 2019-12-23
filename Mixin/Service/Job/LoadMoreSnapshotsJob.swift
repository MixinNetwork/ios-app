import UIKit
import MixinServices

class LoadMoreSnapshotsJob: RefreshSnapshotsJob {
    
    static let didLoadEarliestSnapshotUserInfoKey = "MXNDidLoadEarliestSnapshotUserInfoKey"
    static let jobIdUserInfoKey = "MXNJobIdUserInfoKey"
    
    override func getJobId() -> String {
        let offset = RefreshSnapshotsJob.offset(for: category) ?? ""
        return "load-more-snapshot-\(category)-\(offset)"
    }
    
    override func run() throws {
        let result: APIResult<[Snapshot]>
        switch category {
        case .all:
            result = AssetAPI.shared.snapshots(limit: limit, offset: RefreshSnapshotsJob.offset(for: category))
        case .opponent(let id):
            result = AssetAPI.shared.snapshots(opponentId: id)
        case .asset(let id):
            result = AssetAPI.shared.snapshots(limit: limit, offset: RefreshSnapshotsJob.offset(for: category), assetId: id)
        }
        switch result {
        case let .success(snapshots):
            let userInfo: [String: Any] = [
                LoadMoreSnapshotsJob.jobIdUserInfoKey: getJobId(),
                LoadMoreSnapshotsJob.didLoadEarliestSnapshotUserInfoKey: snapshots.count < limit
            ]
            SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: snapshots, userInfo: userInfo)
            RefreshSnapshotsJob.setOffset(snapshots.last?.createdAt, for: category)
        case let .failure(error):
            throw error
        }
    }
    
}
