import Foundation
import MixinServices

final class PerpetualPositionLoader {
    
    private let walletID: String
    
    private weak var timer: Timer?
    
    init(walletID: String) {
        self.walletID = walletID
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        let timer: Timer = .scheduledTimer(
            withTimeInterval: 3,
            repeats: true
        ) { [walletID] (timer) in
            RouteAPI.positions(
                walletID: walletID,
                queue: .global()
            ) { result in
                switch result {
                case .success(let positions):
                    let different = PerpsPositionDAO.shared.replace(positions: positions)
                    if different {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                            let history = SyncPerpsPositionHistoryJob(walletID: walletID)
                            ConcurrentJobQueue.shared.addJob(job: history)
                        }
                    }
                case .failure(let error):
                    Logger.general.debug(category: "PerpPositionLoader", message: "\(error)")
                }
            }
        }
        self.timer = timer
        timer.fire()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
}
