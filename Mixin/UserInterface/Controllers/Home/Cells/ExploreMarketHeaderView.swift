import UIKit
import MixinServices

final class ExploreMarketHeaderView: UICollectionReusableView {

    protocol Delegate: AnyObject {
        
        func exploreMarketHeaderView(
            _ view: ExploreMarketHeaderView,
            didSwitchToCategory category: Market.Category,
            limit: Market.Limit?
        )
        
        func exploreMarketHeaderView(
            _ view: ExploreMarketHeaderView,
            didSwitchToOrdering order: Market.OrderingExpression,
            changePeriod period: Market.ChangePeriod
        )
        
    }
    
    @IBOutlet weak var segmentedControl: OutlineSegmentedControl!
    @IBOutlet weak var limitButton: ConfigurationBasedOutlineButton!
    @IBOutlet weak var changePeriodButton: ConfigurationBasedOutlineButton!
    @IBOutlet weak var marketCapButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var periodButton: UIButton!
    
    @IBOutlet weak var priceButtonTrailingConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    var limit: Market.Limit? = .top100 {
        didSet {
            UIView.performWithoutAnimation {
                if let limit {
                    limitButton.configuration?.attributedTitle = AttributedString(
                        limit.displayTitle,
                        attributes: filterButtonAttributes
                    )
                    limitButton.menu = UIMenu(children: limitActions(selectedLimit: limit))
                    limitButton.layoutIfNeeded()
                    limitButton.isHidden = false
                } else {
                    limitButton.isHidden = true
                }
            }
        }
    }
    
    var changePeriod: Market.ChangePeriod = .sevenDays {
        didSet {
            UIView.performWithoutAnimation {
                let title = changePeriod.displayTitle
                changePeriodButton.configuration?.attributedTitle = AttributedString(
                    title,
                    attributes: filterButtonAttributes
                )
                changePeriodButton.menu = UIMenu(children: changePeriodActions(selectedPeriod: changePeriod))
                changePeriodButton.layoutIfNeeded()
                periodButton.setTitle(title, for: .normal)
                periodButton.layoutIfNeeded()
            }
        }
    }
    
    var category: Market.Category = .all {
        didSet {
            switch category {
            case .all:
                segmentedControl.selectItem(at: 1)
                UIView.performWithoutAnimation {
                    marketCapButton.setTitle(R.string.localizable.market_cap(), for: .normal)
                    marketCapButton.layoutIfNeeded()
                }
            case .favorite:
                segmentedControl.selectItem(at: 0)
                UIView.performWithoutAnimation {
                    marketCapButton.setTitle(R.string.localizable.watchlist(), for: .normal)
                    marketCapButton.layoutIfNeeded()
                }
            }
        }
    }
    
    var order: Market.OrderingExpression = .marketCap(.descending) {
        didSet {
            iconButton(ordering: oldValue).setImage(nil, for: .normal)
            let button = iconButton(ordering: order)
            button.setImage(R.image.selector_down(), for: .normal)
            switch order.ordering {
            case .ascending:
                button.imageView?.transform = CGAffineTransform(scaleX: 1, y: -1)
            case .descending:
                button.imageView?.transform = .identity
            }
        }
    }
    
    private let filterButtonAttributes = {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        return container
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        segmentedControl.items = [
            R.image.market_favorite_hollow()!,
            R.image.market_rank()!,
        ]
        limitButton.menu = UIMenu(children: limitActions(selectedLimit: .top100))
        limitButton.showsMenuAsPrimaryAction = true
        changePeriodButton.configuration?.attributedTitle = AttributedString(
            changePeriod.displayTitle,
            attributes: filterButtonAttributes
        )
        changePeriodButton.menu = UIMenu(children: changePeriodActions(selectedPeriod: changePeriod))
        changePeriodButton.showsMenuAsPrimaryAction = true
        marketCapButton.semanticContentAttribute = .forceRightToLeft
        priceButton.semanticContentAttribute = .forceRightToLeft
        let priceButtonMargin: CGFloat = switch ScreenWidth.current {
        case .long:
            40
        case .medium:
            20
        case .short:
            10
        }
        priceButtonTrailingConstraint.constant = 20 + 60 + priceButtonMargin - (priceButton.configuration?.contentInsets.trailing ?? 0)
        periodButton.setTitle(changePeriod.displayTitle, for: .normal)
        periodButton.semanticContentAttribute = .forceRightToLeft
        
        // UIButton with image and title failed to calculate intrinsicContentSize if bold text is turned on in iOS Display Settings
        // Set lineBreakMode to byClipping as a workaround. Tested on iOS 17.6.1
        for button: UIButton in [limitButton, changePeriodButton, marketCapButton] {
            button.titleLabel?.lineBreakMode = .byClipping
        }
    }
    
    @IBAction func segmentValueChanged(_ sender: OutlineSegmentedControl) {
        switch sender.selectedItemIndex {
        case 0:
            category = .favorite
            limit = nil
            delegate?.exploreMarketHeaderView(self, didSwitchToCategory: category, limit: limit)
        case 1:
            category = .all
            limit = .top100
            delegate?.exploreMarketHeaderView(self, didSwitchToCategory: category, limit: limit)
        default:
            break
        }
    }
    
    @IBAction func sortByMarketCap(_ sender: Any) {
        order = switch order {
        case let .marketCap(ordering):
                .marketCap(ordering.toggled())
        default:
                .marketCap(.descending)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order, changePeriod: changePeriod)
    }
    
    @IBAction func sortByPrice(_ sender: Any) {
        order = switch order {
        case .price(let ordering):
                .price(ordering.toggled())
        default:
                .price(.descending)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order, changePeriod: changePeriod)
    }
    
    @IBAction func sortByChange(_ sender: Any) {
        order = switch order {
        case let .change(period, ordering):
                .change(period: period, ordering: ordering.toggled())
        default:
                .change(period: changePeriod, ordering: .descending)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order, changePeriod: changePeriod)
    }
    
    private func setLimit(_ limit: Market.Limit) {
        self.limit = limit
        delegate?.exploreMarketHeaderView(self, didSwitchToCategory: category, limit: limit)
    }
    
    private func setChangePeriod(_ period: Market.ChangePeriod) {
        self.changePeriod = period
        switch order {
        case .marketCap, .price:
            break
        case let .change(_, ordering):
            self.order = .change(period: period, ordering: ordering)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order, changePeriod: period)
    }
    
    private func iconButton(ordering: Market.OrderingExpression) -> UIButton {
        switch ordering {
        case .marketCap:
            marketCapButton
        case .price:
            priceButton
        case .change:
            periodButton
        }
    }
    
    private func limitActions(selectedLimit: Market.Limit) -> [UIAction] {
        Market.Limit.allCases.map { limit in
            UIAction(
                title: limit.displayTitle,
                state: limit == selectedLimit ? .on : .off,
                handler: { [weak self] _ in self?.setLimit(limit) }
            )
        }
    }
    
    private func changePeriodActions(selectedPeriod: Market.ChangePeriod) -> [UIAction] {
        Market.ChangePeriod.allCases.map { period in
            UIAction(
                title: period.displayTitle,
                state: period == selectedPeriod ? .on : .off,
                handler: { [weak self] _ in self?.setChangePeriod(period) }
            )
        }
    }
    
}
