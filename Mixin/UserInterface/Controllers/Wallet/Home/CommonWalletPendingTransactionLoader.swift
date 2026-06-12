import Foundation
import MixinServices

final class CommonWalletPendingTransactionLoader {
    
    private let walletID: String
    
    private var reviewPendingTransactionJobID: String?
    
    init(walletID: String) {
        self.walletID = walletID
    }
    
    func start() {
        let jobs = [
            ReviewPendingWeb3RawTransactionJob(walletID: walletID),
            ReviewPendingWeb3TransactionJob(walletID: walletID),
            SyncWeb3OutputJob(assetID: AssetID.btc, walletID: walletID),
        ]
        reviewPendingTransactionJobID = jobs[1].getJobId()
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
    func stop() {
        if let id = reviewPendingTransactionJobID {
            ConcurrentJobQueue.shared.cancelJob(jobId: id)
        }
        reviewPendingTransactionJobID = nil
    }
    
}
