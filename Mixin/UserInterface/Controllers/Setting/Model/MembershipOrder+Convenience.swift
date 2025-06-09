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
            return .buyStars(stars)
        case .none:
            return nil
        }
    }
    
}

extension MembershipOrder {
    
    struct StarRepresentation {
        let count: String
        let unit: String
    }
    
    var incomingStars: StarRepresentation? {
        switch status.knownCase {
        case .paid:
            let count = "+\(stars)"
            let unit = if stars == 1 {
                R.string.localizable.star()
            } else {
                R.string.localizable.stars()
            }
            return StarRepresentation(count: count, unit: unit)
        default:
            return nil
        }
    }
    
    var subscriptionRewards: StarRepresentation? {
        switch category.knownCase {
        case .subscription:
            incomingStars
        default:
            nil
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
