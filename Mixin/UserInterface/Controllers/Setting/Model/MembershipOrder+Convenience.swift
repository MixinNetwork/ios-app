import Foundation
import OrderedCollections
import MixinServices

extension MembershipOrder {
    
    enum Transition {
        case upgrade(SafeMembership.Plan)
        case renew(SafeMembership.Plan)
        case buyStars(Int)
    }
    
    var transition: Transition? {
        switch category.knownCase {
        case .subscription:
            guard let after = SafeMembership.Plan(rawValue: after) else {
                return nil
            }
            let before = SafeMembership.Plan(rawValue: before)
            switch (before, after) {
            case (.none, _), (.basic, .standard), (.standard, .premium):
                return .upgrade(after)
            default:
                return .renew(after)
            }
        case .transaction:
            return .buyStars(transactionsQuantity)
        case .none:
            return nil
        }
    }
    
}

extension MembershipOrder {
    
    static func categorizedByCreatedAt(
        createdAtDescendingOrders orders: [MembershipOrder]
    ) -> OrderedDictionary<String, [MembershipOrder]> {
        var result: OrderedDictionary<String, [MembershipOrder]> = [:]
        for order in orders {
            let date = DateFormatter.iso8601Full.date(from: order.createdAt) ?? Date()
            let formattedDate = DateFormatter.dateSimple.string(from: date)
            var orders = result[formattedDate] ?? []
            orders.append(order)
            result[formattedDate] = orders
        }
        return result
    }
    
}

extension MembershipOrder {
    
    var prettySource: String {
        switch fiatOrder?.source {
        case "app_store":
            "App Store"
        case "google_play":
            "Google Play"
        default:
            switch source {
            case "mixin":
                "Mixin"
            case "mixpay":
                "MixPay"
            default:
                source
            }
        }
    }
    
}

extension MembershipOrder.Status {
    
    var localizedDescription: String {
        switch self {
        case .initial:
            R.string.localizable.pending()
        case .paid:
            R.string.localizable.completed()
        case .cancel:
            R.string.localizable.canceled()
        case .expired:
            R.string.localizable.expired()
        case .failed:
            R.string.localizable.failed()
        case .refund:
            R.string.localizable.refunded()
        }
    }
    
}

extension UnknownableEnum<MembershipOrder.Status> {
    
    var localizedDescription: String {
        switch self {
        case .known(let status):
            status.localizedDescription
        case .unknown(let rawValue):
            rawValue
        }
    }
    
}
