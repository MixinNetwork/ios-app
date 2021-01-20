import Foundation
import UIKit

public class RefreshAssetsJob: AsynchronousJob {
    
    private let assetId: String?
    private var asset: Asset?
    
    public init(assetId: String? = nil) {
        self.assetId = assetId
    }
    
    override public func getJobId() -> String {
        return "refresh-assets-\(assetId ?? "all")"
    }
    
    public override func execute() -> Bool {
        if let assetId = self.assetId {
            AssetAPI.asset(assetId: assetId) { (result) in
                switch result {
                case let .success(asset):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
                    }
                    self.asset = asset
                    self.updateFiats()
                case let .failure(error):
                    reporter.report(error: error)
                    self.finishJob()
                }
            }
        } else {
            AssetAPI.assets { (result) in
                switch result {
                case let .success(assets):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        let localAssetIds = AssetDAO.shared.getAssetIds()
                        if localAssetIds.count > 0 {
                            let remoteAssetIds = assets.map { $0.assetId }
                            let notExistAssetIds = Set<String>(localAssetIds).subtracting(remoteAssetIds)
                            if notExistAssetIds.count > 0 {
                                UserDatabase.current.update(Asset.self,
                                                            assignments: [Asset.column(of: .balance).set(to: "0")],
                                                            where: notExistAssetIds.contains(Asset.column(of: .assetId)))
                            }
                        }

                        AssetDAO.shared.insertOrUpdateAssets(assets: assets)
                    }
                    self.updateFiats()
                case let .failure(error):
                    reporter.report(error: error)
                    self.finishJob()
                }
            }
        }
        return true
    }

    private func updateFiats() {
        AssetAPI.fiats { (result) in
            switch result {
            case let .success(fiatMonies):
                DispatchQueue.main.async {
                    Currency.updateRate(with: fiatMonies)
                }
                if let asset = self.asset {
                    self.updatePendingDeposits(asset: asset)
                    return
                }
            case let .failure(error):
                reporter.report(error: error)
            }
            self.finishJob()
        }
    }

    private func updatePendingDeposits(asset: Asset) {
        AssetAPI.pendingDeposits(assetId: asset.assetId, destination: asset.destination, tag: asset.tag) { (result) in
            switch result {
            case let .success(deposits):
                DispatchQueue.global().async {
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    SnapshotDAO.shared.replacePendingDeposits(assetId: asset.assetId, pendingDeposits: deposits)
                }
                self.updateSnapshots(assetId: asset.assetId)
            case let .failure(error):
                reporter.report(error: error)
                self.finishJob()
            }
        }
    }
    
    private func updateSnapshots(assetId: String) {
        AssetAPI.snapshots(limit: 200, assetId: assetId) { (result) in
            switch result {
             case let .success(snapshots):
                DispatchQueue.global().async {
                    guard !MixinService.isStopProcessMessages else {
                        return
                    }
                    AppGroupUserDefaults.Wallet.assetTransactionsOffset[assetId] = snapshots.last?.createdAt
                    SnapshotDAO.shared.saveSnapshots(snapshots: snapshots)
                }
            case let .failure(error):
                reporter.report(error: error)
            }
            self.finishJob()
        }
    }
    
}
