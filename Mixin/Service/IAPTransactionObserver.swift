import Foundation
import StoreKit
import MixinServices

final class IAPTransactionObserver {
    
    static let global = IAPTransactionObserver()
    
    @MainActor
    var onStatusChange: ((IAPTransactionObserver) -> Void)?
    
    @MainActor
    private(set) var isRunning = false {
        didSet {
            onStatusChange?(self)
        }
    }
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        
    }
    
    @MainActor func listenToTransactionUpdates() {
        assert(Thread.isMainThread)
        guard updates == nil else {
            return
        }
        updates = Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                let orderID = transaction.appAccountToken?.uuidString ?? "nil"
                Logger.general.info(category: "IAP", message: "Got verified txn update: \(orderID)")
                await self.handle(verifiedTransaction: transaction)
            }
        }
    }
    
    func handle(verifiedTransaction transaction: Transaction) async {
        await MainActor.run {
            self.isRunning = true
        }
        if transaction.revocationDate != nil {
            // Revocations are handled by backend
        } else if let expirationDate = transaction.expirationDate, expirationDate < Date() {
            // Already expired
        } else if transaction.isUpgraded {
            // There is an active transaction for a higher level of service.
        } else if let id = transaction.appAccountToken?.uuidString.lowercased() {
            var isFinished = false
            while !isFinished {
                do {
                    Logger.general.info(category: "IAP", message: "Checking order: \(id)")
                    let order = try await SafeAPI.membershipOrder(id: id)
                    switch order.status.knownCase {
                    case .initial:
                        Logger.general.info(category: "IAP", message: "Order Inited: \(id)")
                        try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
                        continue
                    case .paid:
                        Logger.general.info(category: "IAP", message: "Order Paid: \(id)")
                        try? await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
                        let job = RefreshAccountJob()
                        ConcurrentJobQueue.shared.addJob(job: job)
                        MembershipOrderDAO.shared.save(orders: [order])
                        isFinished = true
                        await transaction.finish()
                    case .cancel, .expired, .failed, .refund, .none:
                        // TODO: Handle when user paid but order failed
                        Logger.general.error(category: "IAP", message: "Order Paid: \(id)")
                        isFinished = true
                        await transaction.finish()
                    }
                } catch MixinAPIResponseError.forbidden {
                    // Not my order, should be handled by backend
                    Logger.general.error(category: "IAP", message: "Order forbidden: \(id)")
                    isFinished = true
                    await transaction.finish()
                } catch let error as MixinAPIError where error.worthRetrying {
                    Logger.general.error(category: "IAP", message: "Order failed: \(error)")
                    try? await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
                    continue
                } catch {
                    Logger.general.error(category: "IAP", message: "Order: \(id)\n\(error)")
                    isFinished = true
                    await transaction.finish()
                }
            }
        } else {
            Logger.general.error(category: "IAP", message: "Missing order ID")
        }
        await MainActor.run {
            self.isRunning = false
        }
    }
    
}
