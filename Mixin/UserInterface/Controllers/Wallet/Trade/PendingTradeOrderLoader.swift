import Foundation
import MixinServices

final class PendingTradeOrderLoader {
    
    protocol Delegate: AnyObject {
        // Gets called on background queue
        func pendingSwapOrder(_ loader: PendingTradeOrderLoader, didLoad orders: [TradeOrder])
    }
    
    enum Behavior {
        
        // Sync all orders periodically, including opening ones that updated to closed, until manually paused. Delegate object is not called.
        case syncOrders(walletID: String)
        
        // Load periodically until manually paused
        case watchOpeningLimitOrders(walletID: String)
        
        // Load these orders periodically until all of them are closed
        case watchOrders(orderIDs: [String])
        
        // Load the order periodically until closed
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
        case let .watchOpeningLimitOrders(walletID):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.openOrders(walletID: walletID, type: .limit)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: timeInterval)
                    }
                }
            }
        case let .watchOrders(orderIDs):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.orders(ids: orderIDs)
                if let self {
                    self.delegate?.pendingSwapOrder(self, didLoad: orders)
                    DispatchQueue.main.async {
                        self.scheduleRemoteDataLoading(timeInterval: timeInterval)
                    }
                }
            }
        case .syncOrders, .watchOrder:
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
                case let .syncOrders(walletID):
                    let job = SyncWeb3OrdersJob(
                        walletID: walletID,
                        reloadOpeningOrdersOnFinished: true
                    )
                    ConcurrentJobQueue.shared.addJob(job: job)
                    if let self {
                        await MainActor.run {
                            self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                        }
                    }
                case let .watchOpeningLimitOrders(walletID):
                    let orders = try await RouteAPI.tradeOrders(
                        walletID: walletID,
                        limit: nil,
                        offset: nil,
                        state: .pending,
                    ).filter { order in
                        TradeOrder.OrderType(rawValue: order.orderType) == .limit
                    }
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded \(orders.count) opening limit orders")
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
                    let openOrderIDs = orders.compactMap { order in
                        if TradeOrder.State(rawValue: order.state)?.isOpen ?? false {
                            order.orderID
                        } else {
                            nil
                        }
                    }
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded \(orders.count) orders, \(openOrderIDs.count) of them are open")
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                        if let self, !openOrderIDs.isEmpty {
                            await MainActor.run {
                                self.behavior = .watchOrders(orderIDs: openOrderIDs)
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
                        if TradeOrder.State(rawValue: order.state)?.isOpen ?? false {
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
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
