import UIKit
import MixinServices

final class ExploreMarketHeaderView: UICollectionReusableView {

    protocol Delegate: AnyObject {
        func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToCategory category: Market.Category, limit: Market.Limit?)
        func exploreMarketHeaderView(_ view: ExploreMarketHeaderView, didSwitchToOrdering order: Market.OrderingExpression)
    }
    
    @IBOutlet weak var segmentedControl: OutlineSegmentedControl!
    @IBOutlet weak var limitButton: OutlineButton!
    @IBOutlet weak var changePeriodButton: OutlineButton!
    @IBOutlet weak var marketCapButton: UIButton!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var periodButton: UIButton!
    
    @IBOutlet weak var priceButtonTrailingConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    var limit: Market.Limit? = .top100 {
        didSet {
            UIView.performWithoutAnimation {
                if let limit {
                    limitButton.setTitle(limit.displayTitle, for: .normal)
                    limitButton.menu = UIMenu(children: limitActions(selectedLimit: limit))
                    limitButton.isHidden = false
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
            let title = changePeriod.displayTitle
            changePeriodButton.setTitle(title, for: .normal)
            periodButton.setTitle(title, for: .normal)
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        segmentedControl.items = [
            R.image.market_favorite()!,
            R.image.market_rank()!,
        ]
        limitButton.imageView?.contentMode = .center
        limitButton.semanticContentAttribute = .forceRightToLeft
        limitButton.menu = UIMenu(children: limitActions(selectedLimit: .top100))
        limitButton.showsMenuAsPrimaryAction = true
        limitButton.layer.masksToBounds = true        
        changePeriodButton.imageView?.contentMode = .center
        changePeriodButton.setTitle(changePeriod.displayTitle, for: .normal)
        changePeriodButton.semanticContentAttribute = .forceRightToLeft
        changePeriodButton.showsMenuAsPrimaryAction = true
        changePeriodButton.layer.masksToBounds = true
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
        priceButtonTrailingConstraint.constant = 20 + 60 + priceButtonMargin - priceButton.contentEdgeInsets.right
        periodButton.setTitle(changePeriod.displayTitle, for: .normal)
        periodButton.semanticContentAttribute = .forceRightToLeft
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        limitButton.layer.cornerRadius = limitButton.bounds.height / 2
        changePeriodButton.layer.cornerRadius = limitButton.bounds.height / 2
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
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByPrice(_ sender: Any) {
        order = switch order {
        case .price(let ordering):
                .price(ordering.toggled())
        default:
                .price(.descending)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order)
    }
    
    @IBAction func sortByChange(_ sender: Any) {
        order = switch order {
        case .change(let ordering):
                .change(ordering.toggled())
        default:
                .change(.descending)
        }
        delegate?.exploreMarketHeaderView(self, didSwitchToOrdering: order)
    }
    
    private func setLimit(_ limit: Market.Limit) {
        self.limit = limit
        delegate?.exploreMarketHeaderView(self, didSwitchToCategory: category, limit: limit)
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
    
}
