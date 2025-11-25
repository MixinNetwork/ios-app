import Foundation
import MixinServices

final class PendingTradeOrderLoader {
    
    protocol Delegate: AnyObject {
        // Gets called on background queue
        func pendingSwapOrder(_ loader: PendingTradeOrderLoader, didLoad orders: [TradeOrder])
    }
    
    enum Behavior {
        case watchWallet(walletID: String)
        case watchOrders(orderIDs: [String])
        case watchOrder(id: String, type: TradeOrder.OrderType)
    }
    
    let refreshInterval: TimeInterval = 3
    
    weak var delegate: Delegate?
    
    private var behavior: Behavior
    private var isRunning = false
    
    private weak var timer: Timer?
    
    init(behavior: Behavior) {
        self.behavior = behavior
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start(after timeInterval: TimeInterval) {
        assert(Thread.isMainThread)
        guard !isRunning else {
            return
        }
        isRunning = true
        Logger.general.debug(category: "PendingTradeOrderLoader", message: "Started")
        switch behavior {
        case .watchWallet(let walletID):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.openOrders(walletID: walletID)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: timeInterval)
                    }
                }
            }
        case .watchOrders(let orderIDs):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.orders(ids: orderIDs)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: timeInterval)
                    }
                }
            }
        case .watchOrder:
            scheduleRemoteDataLoading(timeInterval: timeInterval)
        }
    }
    
    func pause() {
        assert(Thread.isMainThread)
        Logger.general.debug(category: "PendingTradeOrderLoader", message: "Paused")
        isRunning = false
        timer?.invalidate()
    }
    
    private func loadFromRemote() {
        assert(Thread.isMainThread)
        timer?.invalidate()
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        Logger.general.debug(category: "PendingTradeOrderLoader", message: "Load from remote")
        Task.detached { [behavior, refreshInterval, weak self] in
            do {
                switch behavior {
                case let .watchWallet(walletID):
                    let orders = try await RouteAPI.tradeOrders(
                        limit: 100, // TODO: What if pending orders more than 100?
                        offset: nil,
                        walletID: walletID,
                        state: .pending,
                    )
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded \(orders.count) orders")
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                    }
                    if let self {
                        self.delegate?.pendingSwapOrder(self, didLoad: orders)
                        await MainActor.run {
                            self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                        }
                    }
                case let .watchOrders(orderIDs):
                    let orders = try await RouteAPI.tradeOrders(ids: orderIDs)
                    let pendingOrderIDs = orders.compactMap { order in
                        switch TradeOrder.State(rawValue: order.state) {
                        case .created, .pending, .cancelling:
                            order.orderID
                        default:
                            nil
                        }
                    }
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded \(orders.count) orders, \(pendingOrderIDs.count) of them are pending")
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                        if let self, !pendingOrderIDs.isEmpty {
                            await MainActor.run {
                                self.behavior = .watchOrders(orderIDs: pendingOrderIDs)
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
                        }
                    }
                    if let self {
                        self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    }
                case let .watchOrder(id, type):
                    let order = switch type {
                    case .swap:
                        try await RouteAPI.swapOrder(id: id)
                    case .limit:
                        try await RouteAPI.limitOrder(id: id)
                    }
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded order \(order.state)")
                    Web3OrderDAO.shared.save(orders: [order])
                    if let self {
                        self.delegate?.pendingSwapOrder(self, didLoad: [order])
                        switch TradeOrder.State(rawValue: order.state) {
                        case .created, .pending:
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
                        default:
                            break
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "\(error)")
                    self?.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                }
            }
        }
    }
    
    private func scheduleRemoteDataLoading(timeInterval: TimeInterval) {
        if timeInterval == 0 {
            loadFromRemote()
        } else {
            Logger.general.debug(category: "PendingTradeOrderLoader", message: "Scheduled loading after \(timeInterval)")
            timer = Timer.scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: false
            ) { [weak self] _ in
                self?.loadFromRemote()
            }
        }
    }
    
}
