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
                if asset.isErrorAddress {
                    var userInfo = UIApplication.getTrackUserInfo()
                    userInfo["chainId"] = asset.chainId
                    userInfo["name"] = asset.name
                    userInfo["symbol"] = asset.symbol
                    userInfo["type"] = asset.type
                    userInfo["assetId"] = asset.assetId
                    userInfo["publicKey"] = asset.publicKey ?? ""
                    userInfo["accountName"] = asset.accountName ?? ""
                    userInfo["accountTag"] = asset.accountTag ?? ""
                    UIApplication.trackError("RefreshAssetsJob", action: "asset deposit data bad", userInfo: userInfo)
                }
                AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
                if asset.isAddress, let key = asset.publicKey {
                    switch AssetAPI.shared.pendingDeposits(assetId: assetId, publicKey: key) {
                    case let .success(deposits):
                        SnapshotDAO.shared.replacePendingDeposits(assetId: assetId, pendingDeposits: deposits)
                    case let .failure(error):
                        UIApplication.trackError("RefreshAssetsJob",
                                                 action: "Get pending deposits",
                                                 userInfo: ["error": error.debugDescription])
                    }
                } else if asset.isAccount, let name = asset.accountName, let tag = asset.accountTag {
                    switch AssetAPI.shared.pendingDeposits(assetId: assetId, accountName: name, accountTag: tag) {
                    case let .success(deposits):
                        SnapshotDAO.shared.replacePendingDeposits(assetId: assetId, pendingDeposits: deposits)
                    case let .failure(error):
                        UIApplication.trackError("RefreshAssetsJob",
                                                 action: "Get pending deposits",
                                                 userInfo: ["error": error.debugDescription])
                    }
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
    }

    private func updateSnapshots(assetId: String) {
        switch AssetAPI.shared.snapshots(assetId: assetId) {
        case let .success(snapshots):
            SnapshotDAO.shared.updateSnapshots(snapshots: snapshots)
        case let .failure(error):
            UIApplication.trackError("RefreshAssetsJob",
                                     action: "Get snapshots",
                                     userInfo: ["error": error.debugDescription])
        }
    }
    
}
