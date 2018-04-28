import Foundation

class RefreshSnapshotsJob: BaseJob {
    private let assetId: String

    init(assetId: String) {
        self.assetId = assetId
    }

    override func getJobId() -> String {
        return "refresh-snapshot-\(assetId)"
    }

    override func run() throws {
        guard !self.assetId.isEmpty else {
            return
        }

        switch AssetAPI.shared.snapshots(assetId: assetId) {
        case let .success(snapshots):
            SnapshotDAO.shared.updateSnapshots(assetId: assetId, snapshots: snapshots)
        case let .failure(error):
            throw error
        }

    }
}

