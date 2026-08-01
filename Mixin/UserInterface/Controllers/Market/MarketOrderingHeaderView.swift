import UIKit
import MixinServices

final class MarketOrderingHeaderView: MarketHeaderView {
    
    protocol Delegate: MarketHeaderView.Delegate {
        func marketOrderingHeaderViewDidSelectSetting(_ view: MarketOrderingHeaderView)
        func marketOrderingHeaderView(_ view: MarketOrderingHeaderView, didSwitchToOrdering order: MarketOrdering)
    }
    
    @IBOutlet weak var leftOrderButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var periodButton: UIButton!
    
    var order: MarketOrdering? {
        didSet {
            if let oldValue {
                iconButton(ordering: oldValue).configuration?.image = R.image.order_none()
            }
            if let order {
                switch order.field {
                case .marketCap, .volume:
                    leftOrderingField = order.field
                case .price, .change:
                    break
                }
                iconButton(ordering: order).configuration?.image = switch order.direction {
                case .ascending:
                    R.image.order_ascending()
                case .descending:
                    R.image.order_descending()
                }
            } else {
                leftOrderButton.configuration?.image = R.image.order_none()
                priceButton.configuration?.image = R.image.order_none()
                periodButton.configuration?.image = R.image.order_none()
            }
        }
    }
    
    var leftOrderingField: MarketOrdering.Field = .marketCap {
        didSet {
            switch leftOrderingField {
            case .marketCap:
                leftOrderButton.configuration?.title = R.string.localizable.market_cap()
            case .volume:
                leftOrderButton.configuration?.title = R.string.localizable.market_volume_short()
            case .price, .change:
                assertionFailure("Not available")
            }
        }
    }
    
    var changePeriod: MarketChangePeriod = .sevenDays {
        didSet {
            periodButton.configuration?.title = changePeriod.displayTitle
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let orderButtonTitleTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
            return outgoing
        }
        leftOrderButton.configuration?.titleTextAttributesTransformer = orderButtonTitleTransformer
        leftOrderButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if var config = priceButton.configuration {
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            config.title = R.string.localizable.price()
            priceButton.configuration = config
        }
        priceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        periodButton.configuration?.titleTextAttributesTransformer = orderButtonTitleTransformer
        periodButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func invokeSetting(_ sender: Any) {
        (delegate as? Delegate)?.marketOrderingHeaderViewDidSelectSetting(self)
    }
    
    @IBAction func sortByMarketCap(_ sender: Any) {
        let order = if let order, order.field == leftOrderingField {
            order.directionToggled()
        } else {
            MarketOrdering(field: leftOrderingField, direction: .descending)
        }
        self.order = order
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByPrice(_ sender: Any) {
        let order = if let order, order.field == .price {
            order.directionToggled()
        } else {
            MarketOrdering(field: .price, direction: .descending)
        }
        self.order = order
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByChange(_ sender: Any) {
        let order = if let order, case .change = order.field {
            order.directionToggled()
        } else {
            MarketOrdering(
                field: .change(period: changePeriod),
                direction: .descending
            )
        }
        self.order = order
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    private func iconButton(ordering: MarketOrdering) -> UIButton {
        switch ordering.field {
        case .marketCap:
            leftOrderButton
        case .volume:
            leftOrderButton
        case .price:
            priceButton
        case .change:
            periodButton
        }
    }
    
}
