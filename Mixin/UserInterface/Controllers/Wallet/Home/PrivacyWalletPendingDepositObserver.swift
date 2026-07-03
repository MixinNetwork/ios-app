import Foundation
import MixinServices

final class PrivacyWalletPendingDepositObserver {
    
    protocol Delegate: AnyObject {
        
        func privacyWalletPendingDepositObserver(
            _ observer: PrivacyWalletPendingDepositObserver,
            didUpdateWith tokens: [MixinToken],
            snapshots: [SafeSnapshot]
        )
        
    }
    
    weak var delegate: Delegate?
    
    private let delegationQueue: DispatchQueue
    
    init(delegationQueue: DispatchQueue) {
        self.delegationQueue = delegationQueue
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPendingDeposits),
            name: UTXOService.balanceDidUpdateNotification,
            object: nil
        )
    }
    
    @objc func reloadPendingDeposits() {
        DispatchQueue.global().async { [weak self, delegationQueue] in
            let snapshots = SafeSnapshotDAO.shared.snapshots(assetID: nil, pending: true, limit: nil)
            let assetIDs = Set(snapshots.map(\.assetID))
            let tokens = TokenDAO.shared.tokens(with: assetIDs)
            delegationQueue.async {
                guard let self else {
                    return
                }
                self.delegate?.privacyWalletPendingDepositObserver(
                    self,
                    didUpdateWith: tokens,
                    snapshots: snapshots
                )
            }
            SafeAPI.allDeposits(queue: .global()) { result in
                guard case .success(let deposits) = result else {
                    return
                }
                let myDeposits = DepositFilter.myDeposits(from: deposits)
                let assetIDs = Set(myDeposits.map(\.assetID))
                
                var tokens = TokenDAO.shared.tokens(with: assetIDs)
                let missingAssetIDs = TokenDAO.shared.inexistAssetIDs(in: assetIDs)
                if !missingAssetIDs.isEmpty {
                    switch SafeAPI.assets(ids: missingAssetIDs) {
                    case .failure(let error):
                        Logger.general.debug(category: "Wallet", message: "\(error)")
                    case .success(let missingTokens):
                        TokenDAO.shared.save(assets: missingTokens)
                        tokens.append(contentsOf: missingTokens)
                    }
                }
                
                SafeSnapshotDAO.shared.replaceAllPendingSnapshots(with: myDeposits)
                let newSnapshots = myDeposits.map(SafeSnapshot.init(pendingDeposit:))
                if snapshots.isEmpty && newSnapshots.isEmpty {
                    return
                }
                delegationQueue.async {
                    guard let self else {
                        return
                    }
                    self.delegate?.privacyWalletPendingDepositObserver(
                        self,
                        didUpdateWith: tokens,
                        snapshots: newSnapshots
                    )
                }
            }
        }
    }
    
}
