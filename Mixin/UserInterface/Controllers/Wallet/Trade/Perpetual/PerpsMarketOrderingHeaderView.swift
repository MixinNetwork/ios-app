import UIKit
import MixinServices

final class PerpsMarketOrderingHeaderView: UICollectionReusableView {
    
    protocol Delegate: AnyObject {
        func perpsMarketOrderingHeaderView(_ view: PerpsMarketOrderingHeaderView, didSwitchToOrdering order: MarketOrdering?)
    }
    
    @IBOutlet weak var volumeButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var periodButton: UIButton!
    
    weak var delegate: Delegate?
    
    var order: MarketOrdering? {
        didSet {
            if let oldValue {
                iconButton(ordering: oldValue).configuration?.image = R.image.order_none()
            }
            if let order {
                iconButton(ordering: order).configuration?.image = switch order.direction {
                case .ascending:
                    R.image.order_ascending()
                case .descending:
                    R.image.order_descending()
                }
            } else {
                volumeButton.configuration?.image = R.image.order_none()
                priceButton.configuration?.image = R.image.order_none()
                periodButton.configuration?.image = R.image.order_none()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let orderButtonTitleTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
            return outgoing
        }
        if var config = volumeButton.configuration {
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            config.title = R.string.localizable.market_volume_short()
            volumeButton.configuration = config
        }
        volumeButton.titleLabel?.adjustsFontForContentSizeCategory = true
        if var config = priceButton.configuration {
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            config.title = R.string.localizable.price()
            priceButton.configuration = config
        }
        priceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        periodButton.configuration?.titleTextAttributesTransformer = orderButtonTitleTransformer
        periodButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func sortByMarketCap(_ sender: Any) {
        self.order = if let order, order.field == .volume {
            switch order.direction {
            case .ascending:
                nil
            case .descending:
                order.directionToggled()
            }
        } else {
            MarketOrdering(field: .volume, direction: .descending)
        }
        delegate?.perpsMarketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByPrice(_ sender: Any) {
        self.order = if let order, order.field == .price {
            switch order.direction {
            case .ascending:
                nil
            case .descending:
                order.directionToggled()
            }
        } else {
            MarketOrdering(field: .price, direction: .descending)
        }
        delegate?.perpsMarketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByChange(_ sender: Any) {
        self.order = if let order, case .change = order.field {
            switch order.direction {
            case .ascending:
                nil
            case .descending:
                order.directionToggled()
            }
        } else {
            MarketOrdering(
                field: .change(period: .twentyFourHours),
                direction: .descending
            )
        }
        delegate?.perpsMarketOrderingHeaderView(self, didSwitchToOrdering: order)
    }
    
    private func iconButton(ordering: MarketOrdering) -> UIButton {
        switch ordering.field {
        case .marketCap:
            volumeButton
        case .volume:
            volumeButton
        case .price:
            priceButton
        case .change:
            periodButton
        }
    }
    
}
