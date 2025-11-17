import Foundation
import MixinServices

final class PendingSwapOrderLoader {
    
    protocol Delegate: AnyObject {
        // Gets called on background queue
        func pendingSwapOrder(_ loader: PendingSwapOrderLoader, didLoad orders: [SwapOrder])
    }
    
    enum Behavior {
        case watchWallet(id: String)
        case watchOrders(ids: [String])
        case watchOrder(id: String)
    }
    
    weak var delegate: Delegate?
    
    private let refreshInterval: TimeInterval = 10
    
    private var behavior: Behavior
    private var isRunning = false
    
    private weak var timer: Timer?
    
    init(behavior: Behavior) {
        self.behavior = behavior
    }
    
    func start() {
        assert(Thread.isMainThread)
        guard !isRunning else {
            return
        }
        isRunning = true
        Logger.general.debug(category: "PendingSwapOrderLoader", message: "Started")
        switch behavior {
        case .watchWallet(let id):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.pendingOrders(walletID: id)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: 0)
                    }
                }
            }
        case .watchOrders(let ids):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.orders(ids: ids)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: 0)
                    }
                }
            }
        case .watchOrder:
            scheduleRemoteDataLoading(timeInterval: 0)
        }
    }
    
    func pause() {
        assert(Thread.isMainThread)
        Logger.general.debug(category: "PendingSwapOrderLoader", message: "Paused")
        isRunning = false
        timer?.invalidate()
    }
    
    private func loadFromRemote() {
        assert(Thread.isMainThread)
        timer?.invalidate()
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        Logger.general.debug(category: "PendingSwapOrderLoader", message: "Load from remote")
        Task.detached { [behavior, refreshInterval, weak self] in
            do {
                switch behavior {
                case .watchWallet:
                    let orders = try await RouteAPI.swapOrders(
                        limit: 100, // TODO: What if pending orders more than 100?
                        offset: nil,
                        walletID: nil,
                        state: .pending,
                    )
                    Logger.general.debug(category: "PendingSwapOrderLoader", message: "Loaded \(orders.count) orders")
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                        if let self {
                            self.delegate?.pendingSwapOrder(self, didLoad: orders)
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
                        }
                    }
                case .watchOrders(let ids):
                    let orders = try await RouteAPI.swapOrders(ids: ids)
                    Logger.general.debug(category: "PendingSwapOrderLoader", message: "Loaded \(orders.count) orders")
                    Web3OrderDAO.shared.save(orders: orders)
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                        if let self {
                            self.delegate?.pendingSwapOrder(self, didLoad: orders)
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
                        }
                    }
                case .watchOrder(let id):
                    let order = try await RouteAPI.limitOrder(id: id)
                    Logger.general.debug(category: "PendingSwapOrderLoader", message: "Loaded order \(order.state)")
                    Web3OrderDAO.shared.save(orders: [order])
                    if let self {
                        self.delegate?.pendingSwapOrder(self, didLoad: [order])
                        if SwapOrder.State(rawValue: order.state) == .pending {
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    Logger.general.debug(category: "PendingSwapOrderLoader", message: "\(error)")
                    self?.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                }
            }
        }
    }
    
    private func scheduleRemoteDataLoading(timeInterval: TimeInterval) {
        if timeInterval == 0 {
            loadFromRemote()
        } else {
            Logger.general.debug(category: "PendingSwapOrderLoader", message: "Scheduled loading after \(timeInterval)")
            timer = Timer.scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: false
            ) { [weak self] _ in
                self?.loadFromRemote()
            }
        }
    }
    
}
