import Foundation
import OrderedCollections
import MixinServices

extension MembershipOrder {
    
    public enum Transition {
        case upgrade
        case renew
    }
    
    public var transition: Transition {
        switch (before.knownCase, after.knownCase) {
        case (.none, _), (.basic, .standard), (.standard, .premium):
                .upgrade
        default:
                .renew
        }
    }
    
}

extension MembershipOrder {
    
    public static func categorizedByCreatedAt(
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
