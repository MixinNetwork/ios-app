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
                    AssetAPI.chains { result in
                        switch result {
                        case let .success(chains):
                            DispatchQueue.global().async {
                                guard !MixinService.isStopProcessMessages else {
                                    return
                                }
                                ChainDAO.shared.save(chains)
                                Web3ChainDAO.shared.save(chains)
                            }
                        case let .failure(error):
                            if error.worthReporting {
                                reporter.report(error: error)
                            }
                        }
                        self.updateFiats()
                    }
                case let .failure(error):
                    if error.worthReporting {
                        reporter.report(error: error)
                    }
                    self.finishJob()
                }
            }
        case .asset(let id, let untilDepositEntriesNotEmpty):
            AssetAPI.asset(assetId: id) { (result) in
                switch result {
                case let .success(asset):
                    if untilDepositEntriesNotEmpty && asset.depositEntries.isEmpty {
                        Logger.general.warn(category: "RefreshAssetsJob", message: "Asset: \(id) is returned with an empty deposit_entries")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            if !self.isCancelled {
                                self.execute()
                            }
                        }
                    } else {
                        DispatchQueue.global().async {
                            guard !MixinService.isStopProcessMessages else {
                                return
                            }
                            AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
                        }
                        self.asset = asset
                        AssetAPI.chain(chainId: asset.chainId) { result in
                            switch result {
                            case let .success(chain):
                                DispatchQueue.global().async {
                                    guard !MixinService.isStopProcessMessages else {
                                        return
                                    }
                                    ChainDAO.shared.save([chain])
                                    Web3ChainDAO.shared.save([chain])
                                }
                            case let .failure(error):
                                if error.worthReporting {
                                    reporter.report(error: error)
                                }
                            }
                            self.updateFiats()
                        }
                    }
                case let .failure(error):
                    if error.worthReporting {
                        reporter.report(error: error)
                    }
                    self.finishJob()
                }
            }
        }
        return true
    }

    private func updateFiats() {
        ExternalAPI.fiats { (result) in
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
                if error.worthReporting {
                    reporter.report(error: error)
                }
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
                    if error.worthReporting {
                        reporter.report(error: error)
                    }
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
                    SnapshotDAO.shared.saveSnapshots(snapshots: snapshots)
                }
            case let .failure(error):
                if error.worthReporting {
                    reporter.report(error: error)
                }
            }
            self.finishJob()
        }
    }
    
}
