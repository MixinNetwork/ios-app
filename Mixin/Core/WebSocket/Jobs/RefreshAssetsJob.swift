import Foundation
import UIKit

class RefreshAssetsJob: BaseJob {

    private let assetId: String?

    init(assetId: String? = nil) {
        self.assetId = assetId
    }

    override func getJobId() -> String {
        return "refresh-assets-\(assetId ?? "all")"
    }

    override func run() throws {
        if let assetId = self.assetId {
            switch AssetAPI.shared.asset(assetId: assetId) {
            case let .success(asset):
                AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
                switch AssetAPI.shared.pendingDeposits(assetId: assetId, destination: asset.destination, tag: asset.tag) {
                case let .success(deposits):
                    SnapshotDAO.shared.replacePendingDeposits(assetId: assetId, pendingDeposits: deposits)
                case let .failure(error):
                    UIApplication.traceError(error)
                }
                updateSnapshots(assetId: assetId)
            case let .failure(error):
                throw error
            }
        } else {
            switch AssetAPI.shared.assets() {
            case let .success(assets):
                AssetDAO.shared.insertOrUpdateAssets(assets: assets)
            case let .failure(error):
                throw error
            }
        }
        switch AssetAPI.shared.fiats() {
        case let .success(fiatMonies):
            DispatchQueue.main.async {
                Currency.updateRate(with: fiatMonies)
            }
        case let .failure(error):
            UIApplication.traceError(error)
        }
    }

    private func updateSnapshots(assetId: String) {
        switch AssetAPI.shared.snapshots(limit: 200, assetId: assetId) {
        case let .success(snapshots):
            WalletUserDefault.shared.assetTransactionOffset[assetId] = snapshots.last?.createdAt
            SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: snapshots)
        case let .failure(error):
            UIApplication.traceError(error)
        }
    }
    
}
