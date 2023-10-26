import UIKit
import MixinServices

class LoadMoreSnapshotsJob: RefreshSnapshotsJob {
    
    static let didLoadEarliestSnapshotUserInfoKey = "MXMDidLoadEarliestSnapshotUserInfoKey"
    static let jobIdUserInfoKey = "MXMJobIdUserInfoKey"
    
    override func getJobId() -> String {
        let offset = RefreshSnapshotsJob.offset(for: category) ?? ""
        return "load-more-snapshot-\(category)-\(offset)"
    }
    
    override func run() throws {
        let result: MixinAPI.Result<[SafeSnapshot]>
        switch category {
        case .all:
            result = SafeAPI.snapshots(asset: nil, opponent: nil, offset: RefreshSnapshotsJob.offset(for: category), limit: limit)
        case .opponent(let id):
            result = SafeAPI.snapshots(asset: nil, opponent: id, offset: RefreshSnapshotsJob.offset(for: category), limit: limit)
        case .asset(let id):
            result = SafeAPI.snapshots(asset: id, opponent: nil, offset: RefreshSnapshotsJob.offset(for: category), limit: limit)
        }
        switch result {
        case let .success(snapshots):
            let userInfo: [String: Any] = [
                LoadMoreSnapshotsJob.jobIdUserInfoKey: getJobId(),
                LoadMoreSnapshotsJob.didLoadEarliestSnapshotUserInfoKey: snapshots.count < limit
            ]
            SafeSnapshotDAO.shared.save(snapshots: snapshots, userInfo: userInfo)
            RefreshSnapshotsJob.setOffset(snapshots.last?.createdAt.toUTCString(), for: category)
        case let .failure(error):
            throw error
        }
    }
    
}
