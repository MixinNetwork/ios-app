import Foundation
import MixinServices

final class SyncPerpsPositionHistoryJob: AsynchronousJob {

    private let walletID: String
    private let limit = 100
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    public override func getJobId() -> String {
        "sync-perps-position-history-\(walletID)"
    }
    
    public override func execute() -> Bool {
        let initialOffset = PerpsPositionHistoryDAO.shared.offset()
        Logger.general.debug(category: "SyncPerpsPositionHistory", message: "wid: \(walletID), offset: \(initialOffset ?? "(null)")")
        Task {
            do {
                var history = try await RouteAPI.positionsHistory(
                    walletID: walletID,
                    offset: initialOffset,
                    limit: limit
                )
                while true {
                    Logger.general.debug(category: "SyncPerpsPositionHistory", message: "Write \(history.count) history")
                    PerpsPositionHistoryDAO.shared.save(positions: history)
                    if let offset = history.last, history.count >= limit {
                        history = try await RouteAPI.positionsHistory(
                            walletID: walletID,
                            offset: offset.closedAt,
                            limit: limit
                        )
                    } else {
                        Logger.general.debug(category: "SyncPerpsPositionHistory", message: "Sync finished")
                        break
                    }
                }
            } catch {
                Logger.general.debug(category: "SyncPerpsPositionHistory", message: "\(error)")
            }
            finishJob()
        }
        return true
    }
    
}
