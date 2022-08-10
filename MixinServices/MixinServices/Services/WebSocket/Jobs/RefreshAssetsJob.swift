import Foundation
import UIKit

public class RefreshAssetsJob: AsynchronousJob {
    
    public enum Request {
        
        case allAssets
        case asset(id: String, untilDepositEntriesNotEmpty: Bool)
        
        var id: String {
            switch self {
            case .allAssets:
                return "all"
            case .asset(let id, let untilDepositEntriesNotEmpty):
                if untilDepositEntriesNotEmpty {
                    return id + "-uden"
                } else {
                    return id
                }
            }
        }
    }
    
    private let request: Request
    
    private var asset: Asset?
    
    public init(request: Request) {
        self.request = request
    }
    
    override public func getJobId() -> String {
        return "refresh-assets-" + request.id
    }
    
    public override func execute() -> Bool {
        switch request {
        case .allAssets:
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
        case .asset(let id, let untilDepositEntriesNotEmpty):
            Logger.general.info(category: "RefreshAssetsJob", message: "Loading asset: \(id)\n\(Thread.callStackSymbols)")
            AssetAPI.asset(assetId: id) { (result) in
                switch result {
                case let .success(asset):
                    Logger.general.info(category: "RefreshAssetsJob", message: "Asset: \(id) is returned with deposit_entries: \(asset.depositEntries)")
                    if untilDepositEntriesNotEmpty && asset.depositEntries.isEmpty {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            if !self.isCancelled {
                                Logger.general.info(category: "RefreshAssetsJob", message: "Asset: \(id) refresh again for deposit_entries")
                                self.execute()
                            }
                        }
                    } else {
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                Logger.general.info(category: "RefreshAssetsJob", message: "Give up saving asset: \(id)")
                                return
                            }
                            Logger.general.info(category: "RefreshAssetsJob", message: "Saving asset: \(id) with \(asset.depositEntries.count) deposit_entries")
                            AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
                        }
                        self.asset = asset
                        self.updateFiats()
                    }
                case let .failure(error):
                    Logger.general.info(category: "RefreshAssetsJob", message: "Failed to load asset: \(id), error: \(error)")
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
                } else {
                    self.finishJob()
                }
            case let .failure(error):
                reporter.report(error: error)
                self.finishJob()
            }
        }
    }

    private func updatePendingDeposits(asset: Asset) {
        var finishedEntryCount = 0
        for entry in asset.depositEntries {
            AssetAPI.pendingDeposits(assetId: asset.assetId, destination: entry.destination, tag: entry.tag) { (result) in
                switch result {
                case let .success(deposits):
                    DispatchQueue.global().async {
                        guard !MixinService.isStopProcessMessages else {
                            return
                        }
                        SnapshotDAO.shared.replacePendingDeposits(assetId: asset.assetId, pendingDeposits: deposits)
                    }
                    finishedEntryCount += 1
                    if finishedEntryCount == asset.depositEntries.count {
                        self.updateSnapshots(assetId: asset.assetId)
                    }
                case let .failure(error):
                    reporter.report(error: error)
                    finishedEntryCount += 1
                    if finishedEntryCount == asset.depositEntries.count {
                        self.updateSnapshots(assetId: asset.assetId)
                    }
                }
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
