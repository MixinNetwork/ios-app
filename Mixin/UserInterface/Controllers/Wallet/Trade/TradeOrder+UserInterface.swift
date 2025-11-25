import Foundation
import MixinServices

extension TradeOrder {
    
    enum Expiry: CaseIterable {
        
        case never
        case tenMinutes
        case oneHour
        case oneDay
        case threeDays
        case oneWeek
        case oneMonth
        
        var localizedName: String {
            switch self {
            case .never:
                R.string.localizable.trade_expiry_never()
            case .tenMinutes:
                R.string.localizable.minute_count(10)
            case .oneHour:
                R.string.localizable.one_hour()
            case .oneDay:
                R.string.localizable.one_day()
            case .threeDays:
                R.string.localizable.days_count(3)
            case .oneWeek:
                R.string.localizable.one_week()
            case .oneMonth:
                R.string.localizable.one_month()
            }
        }
        
        var date: Date {
            switch self {
            case .never:
                    .distantFuture
            case .tenMinutes:
                    .now.addingTimeInterval(10 * .minute)
            case .oneHour:
                    .now.addingTimeInterval(.hour)
            case .oneDay:
                    .now.addingTimeInterval(.day)
            case .threeDays:
                    .now.addingTimeInterval(.day)
            case .oneWeek:
                    .now.addingTimeInterval(.week)
            case .oneMonth:
                    .now.addingTimeInterval(.month)
            }
        }
        
    }
    
    enum Sorting {
        case newest
        case oldest
    }
    
    enum Status {
        
        case pending
        case done
        case other
        
        var states: [TradeOrder.State] {
            switch self {
            case .pending:
                [.created, .pending]
            case .done:
                [.success, .failed, .cancelled, .expired]
            case .other:
                [.cancelling]
            }
        }
        
    }
    
    struct Filter: CustomStringConvertible {
        
        // For array-type properties, when the value is empty,
        // it indicates that this filter should not be applied.
        
        var wallets: [Wallet]
        var type: OrderType?
        var status: Status?
        var startDate: Date?
        var endDate: Date?
        
        var description: String {
            "<Filter wallets: \(wallets), type: \(String(describing: type)), status: \(String(describing: status)), startDate: \(String(describing: startDate)), endDate: \(String(describing: endDate))>"
        }
        
        init(
            wallets: [Wallet] = [],
            type: OrderType? = nil,
            status: Status? = nil,
            startDate: Date? = nil,
            endDate: Date? = nil
        ) {
            self.wallets = wallets
            self.type = type
            self.status = status
            self.startDate = startDate
            self.endDate = endDate
        }
        
        func isIncluded(order: TradeOrder) -> Bool {
            var isIncluded = true
            if !wallets.isEmpty {
                isIncluded = isIncluded && wallets.contains(where: { wallet in
                    switch wallet {
                    case .privacy:
                        order.walletID == myUserId
                    case .common(let wallet):
                        order.walletID == wallet.walletID
                    }
                })
            }
            if let type {
                isIncluded = isIncluded && order.orderType == type.rawValue
            }
            if let states = status?.states, let state = TradeOrder.State(rawValue: order.state) {
                isIncluded = isIncluded && states.contains(state)
            }
            if let startDate {
                isIncluded = isIncluded && order.createdAt.toUTCDate() >= startDate
            }
            if let endDate {
                isIncluded = isIncluded && order.createdAt.toUTCDate() <= endDate
            }
            return isIncluded
        }
        
    }
    
}

extension TradeOrder.State: AnyLocalized {
    
    var localizedDescription: String {
        switch self {
        case .created:
            R.string.localizable.created()
        case .pending:
            R.string.localizable.pending()
        case .success:
            R.string.localizable.completed()
        case .failed:
            R.string.localizable.failed()
        case .cancelling:
            R.string.localizable.cancelling()
        case .cancelled:
            R.string.localizable.canceled()
        case .expired:
            R.string.localizable.expired()
        }
    }
    
}

extension TradeOrder.OrderType: AnyLocalized {
    
    var localizedDescription: String {
        switch self {
        case .swap:
            R.string.localizable.order_type_swap()
        case .limit:
            R.string.localizable.order_type_limit()
        }
    }
    
}
