import Foundation
import UIKit

class RefreshSnapshotsJob: BaseJob {
    
    private let opponentId: String
    
    init(opponentId: String) {
        self.opponentId = opponentId
    }
    
    override func getJobId() -> String {
        return "refresh-snapshot-\(opponentId)"
    }
    
    override func run() throws {
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
