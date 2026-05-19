import Foundation
import MixinServices

final class PerpetualPositionLoader {
    
    private let walletID: String
    
    private weak var timer: Timer?
    
    private var isRunning = false
    
    init(walletID: String) {
        self.walletID = walletID
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        assert(Thread.isMainThread)
        guard timer == nil else {
            return
        }
        isRunning = true
        let timer: Timer = .scheduledTimer(
            withTimeInterval: 3,
            repeats: true
        ) { [walletID] (timer) in
            RouteAPI.positions(
                walletID: walletID,
                queue: .global()
            ) { [weak self] result in
                let isRunning = self?.isRunning ?? false
                guard isRunning else {
                    return
                }
                switch result {
                case .success(let positions):
                    let different = PerpsPositionDAO.shared.replace(positions: positions)
                    if different {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                            let orders = SyncPerpsOrdersJob(walletID: walletID)
                            ConcurrentJobQueue.shared.addJob(job: orders)
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
        assert(Thread.isMainThread)
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
}
