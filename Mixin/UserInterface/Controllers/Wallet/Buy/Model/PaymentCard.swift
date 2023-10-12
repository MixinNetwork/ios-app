import UIKit
import MixinServices

struct PaymentCard {
    
    let scheme: String
    let instrumentID: String
    let postfix: String
    
    var schemeImage: UIImage? {
        switch scheme {
        case "visa":
            return R.image.wallet.visa()
        case "mastercard":
            return R.image.wallet.mastercard()
        case "amex":
            return R.image.wallet.amex()
        case "jcb":
            return R.image.wallet.jcb()
        default:
            return nil
        }
    }
    
}

extension PaymentCard: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.instrumentID == rhs.instrumentID
    }
    
}

extension PaymentCard: Codable {
    
    enum CodingKeys: String, CodingKey {
        case scheme
        case instrumentID = "instrument_id"
        case postfix = "last4"
    }
    
}

extension PaymentCard {
    
    static func cards() -> [PaymentCard]? {
        guard let cards = AppGroupUserDefaults.User.paymentCards else {
            return nil
        }
        let decoder = PropertyListDecoder()
        return cards.compactMap { data in
            try? decoder.decode(PaymentCard.self, from: data)
        }
    }
    
    static func save(_ card: PaymentCard) {
        var cards = Self.cards() ?? []
        guard !cards.contains(card) else {
            return
        }
        cards.append(card)
        let encoder = PropertyListEncoder()
        AppGroupUserDefaults.User.paymentCards = cards.compactMap { card in
            try? encoder.encode(card)
        }
    }
    
    static func replace(_ cards: [PaymentCard]) {
        let encoder = PropertyListEncoder()
        AppGroupUserDefaults.User.paymentCards = cards.compactMap { card in
            try? encoder.encode(card)
        }
    }
    
    static func remove(_ card: PaymentCard) {
        let cards = (Self.cards() ?? []).filter { member in
            member != card
        }
        let encoder = PropertyListEncoder()
        AppGroupUserDefaults.User.paymentCards = cards.compactMap { card in
            try? encoder.encode(card)
        }
    }
    
}
