import UIKit
import MixinServices

final class MarketOrderingHeaderView: MarketHeaderView {
    
    enum LeftOrderingField {
        case marketCap
        case volume
    }
    
    protocol Delegate: MarketHeaderView.Delegate {
        func marketOrderingHeaderViewDidSelectSetting(_ view: MarketOrderingHeaderView)
        func marketOrderingHeaderView(_ view: MarketOrderingHeaderView, didSwitchToOrdering order: MarketDashboardOrder)
    }
    
    @IBOutlet weak var leftOrderButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var periodButton: UIButton!
    
    @IBOutlet weak var leftOrderLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var periodWidthConstraint: NSLayoutConstraint!
    
    var order: MarketDashboardOrder? {
        didSet {
            if let oldValue {
                iconButton(ordering: oldValue)?.configuration?.image = R.image.order_none()
            }
            if let order, let button = iconButton(ordering: order) {
                button.configuration?.image = switch order.direction {
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
    
    var leftOrderingField: LeftOrderingField = .marketCap {
        didSet {
            switch leftOrderingField {
            case .marketCap:
                leftOrderButton.configuration?.title = R.string.localizable.market_cap()
            case .volume:
                leftOrderButton.configuration?.title = R.string.localizable.market_volume_short()
            }
        }
    }
    
    var changePeriod: MarketChangePeriod = .sevenDays {
        didSet {
            periodButton.configuration?.title = changePeriod.displayTitle
        }
    }
    
    var isScoreOrderingAvailable = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let orderButtonTitleTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .caption1)
            return outgoing
        }
        
        if var config = leftOrderButton.configuration {
            leftOrderLeadingConstraint.constant = MarketLayout.mainItemLeadingMargin - config.contentInsets.leading
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            leftOrderButton.configuration = config
        }
        leftOrderButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        if var config = priceButton.configuration {
            priceWidthConstraint.constant = MarketLayout.priceItemWidth
                + MarketLayout.priceItemTrailingMargin / 2
            config.contentInsets.trailing = MarketLayout.priceItemTrailingMargin / 2
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            config.title = R.string.localizable.price()
            priceButton.configuration = config
        }
        priceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        if var config = periodButton.configuration {
            periodWidthConstraint.constant = MarketLayout.priceItemTrailingMargin / 2
                + MarketLayout.changeItemWidth
                + MarketLayout.changeItemTrailingMargin
            config.contentInsets.trailing = MarketLayout.changeItemTrailingMargin
            config.titleTextAttributesTransformer = orderButtonTitleTransformer
            periodButton.configuration = config
        }
        periodButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func invokeSetting(_ sender: Any) {
        (delegate as? Delegate)?.marketOrderingHeaderViewDidSelectSetting(self)
    }
    
    @IBAction func sortByLeftOrder(_ sender: Any) {
        guard let order else {
            return
        }
        let newOrder: MarketDashboardOrder
        switch order {
        case .crypto(let oldOrder):
            let field: Market.Ordering.Field = switch leftOrderingField {
            case .marketCap:
                .marketCap
            case .volume:
                .volume
            }
            if oldOrder.field == field {
                newOrder = .crypto(oldOrder.directionToggled())
            } else {
                newOrder = .crypto(Market.Ordering(field: field, direction: .descending))
            }
        case .perps(let oldOrder):
            if oldOrder.field == .volume {
                switch oldOrder.direction {
                case .ascending where isScoreOrderingAvailable:
                    newOrder = .perps(PerpetualMarket.Ordering(field: .score, direction: .descending))
                case .ascending, .descending:
                    newOrder = .perps(oldOrder.directionToggled())
                }
            } else {
                newOrder = .perps(PerpetualMarket.Ordering(field: .volume, direction: .descending))
            }
        }
        self.order = newOrder
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: newOrder)
    }
    
    @IBAction func sortByPrice(_ sender: Any) {
        guard let order else {
            return
        }
        let newOrder: MarketDashboardOrder
        switch order {
        case .crypto(let oldOrder):
            if oldOrder.field == .price {
                newOrder = .crypto(oldOrder.directionToggled())
            } else {
                newOrder = .crypto(Market.Ordering(field: .price, direction: .descending))
            }
        case .perps(let oldOrder):
            if oldOrder.field == .price {
                switch oldOrder.direction {
                case .ascending where isScoreOrderingAvailable:
                    newOrder = .perps(PerpetualMarket.Ordering(field: .score, direction: .descending))
                case .ascending, .descending:
                    newOrder = .perps(oldOrder.directionToggled())
                }
            } else {
                newOrder = .perps(PerpetualMarket.Ordering(field: .price, direction: .descending))
            }
        }
        self.order = newOrder
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: newOrder)
    }
    
    @IBAction func sortByChange(_ sender: Any) {
        guard let order else {
            return
        }
        let newOrder: MarketDashboardOrder
        switch order {
        case .crypto(let oldOrder):
            if case .change = oldOrder.field {
                newOrder = .crypto(oldOrder.directionToggled())
            } else {
                newOrder = .crypto(Market.Ordering(field: .change(changePeriod), direction: .descending))
            }
        case .perps(let oldOrder):
            if oldOrder.field == .change {
                switch oldOrder.direction {
                case .ascending where isScoreOrderingAvailable:
                    newOrder = .perps(PerpetualMarket.Ordering(field: .score, direction: .descending))
                case .ascending, .descending:
                    newOrder = .perps(oldOrder.directionToggled())
                }
            } else {
                newOrder = .perps(PerpetualMarket.Ordering(field: .change, direction: .descending))
            }
        }
        self.order = newOrder
        (delegate as? Delegate)?.marketOrderingHeaderView(self, didSwitchToOrdering: newOrder)
    }
    
    private func iconButton(ordering: MarketDashboardOrder) -> UIButton? {
        switch ordering {
        case .crypto(let marketOrder):
            switch marketOrder.field {
            case .marketCap, .volume:
                leftOrderButton
            case .price:
                priceButton
            case .change:
                periodButton
            case .apiOrder, .addedAt:
                nil
            }
        case .perps(let perpsOrder):
            switch perpsOrder.field {
            case .volume:
                leftOrderButton
            case .price:
                priceButton
            case .change:
                periodButton
            case .score, .addedAt:
                nil
            }
        }
    }
    
}
