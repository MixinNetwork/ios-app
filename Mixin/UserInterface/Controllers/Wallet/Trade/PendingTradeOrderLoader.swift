import Foundation
import MixinServices

final class PendingTradeOrderLoader {
    
    protocol Delegate: AnyObject {
        // Gets called on background queue
        func pendingSwapOrder(_ loader: PendingTradeOrderLoader, didLoad orders: [TradeOrder])
    }
    
    enum Behavior {
        
        // Load open orders periodically
        // If `type` is swap, it stops when there's no open orders
        // If `type` is limit, it keeps requesting forever
        case watchWallet(walletID: String, type: TradeOrder.OrderType)
        
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
        case let .watchWallet(walletID, type):
            DispatchQueue.global().async { [weak self] in
                let orders = Web3OrderDAO.shared.openOrders(walletID: walletID, type: type)
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
                case let .watchWallet(walletID, type):
                    let orders = try await RouteAPI.tradeOrders(
                        limit: 100, // TODO: What if pending orders more than 100?
                        offset: nil,
                        walletID: walletID,
                        state: .pending,
                    ).filter { order in
                        TradeOrder.OrderType(rawValue: order.orderType) == type
                    }
                    Logger.general.debug(category: "PendingTradeOrderLoader", message: "Loaded \(orders.count) pending \(type.rawValue) orders")
                    if !orders.isEmpty {
                        Web3OrderDAO.shared.save(orders: orders)
                    }
                    if let self {
                        self.delegate?.pendingSwapOrder(self, didLoad: orders)
                        if type == .limit || !orders.isEmpty {
                            await MainActor.run {
                                self.scheduleRemoteDataLoading(timeInterval: refreshInterval)
                            }
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
