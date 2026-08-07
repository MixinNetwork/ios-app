import UIKit
import MixinServices

final class MarketDisplaySettingsViewController: PopupSelectorViewController {
    
    enum Row: Int, CaseIterable {
        case quoteColor
        case priceChange
    }
    
    private let rows: [Row]
    
    init(rows: [Row]) {
        self.rows = rows
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        titleView.backgroundColor = R.color.background_secondary()
        titleView.titleLabel.text = R.string.localizable.market_display()
        tableView.backgroundColor = R.color.background_secondary()
        tableView.rowHeight = 72
        tableView.register(R.nib.marketDisplaySettingCell)
        tableView.dataSource = self
    }
    
    override func updatePreferredContentHeight() {
        preferredContentSize.height = titleHeightConstraint.constant
        + tableViewTopConstraint.constant
        + tableView.contentSize.height
        + tableView.adjustedContentInset.vertical
        + tableViewBottomConstraint.constant
        + 120
    }
    
    private func setQuoteColor(_ appearance: MarketColorAppearance) {
        AppGroupUserDefaults.User.marketColorAppearance = appearance
        if let row = rows.firstIndex(of: .quoteColor) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    private func setPriceChange(period: MarketChangePeriod) {
        AppGroupUserDefaults.User.cryptoMarketChangePeriod = period
        if let row = rows.firstIndex(of: .priceChange) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
}

extension MarketDisplaySettingsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_display_setting, for: indexPath)!
        switch rows[indexPath.row] {
        case .quoteColor:
            let selected = AppGroupUserDefaults.User.marketColorAppearance
            cell.titleLabel.text = R.string.localizable.quote_color()
            cell.subtitleLabel.text = selected.description
            cell.actionButton.menu = UIMenu(children: MarketColorAppearance.allCases.map { appearance in
                UIAction(
                    title: appearance.description,
                    image: appearance.image,
                    state: appearance == selected ? .on : .off,
                    handler: { [weak self] _ in self?.setQuoteColor(appearance) }
                )
            })
        case .priceChange:
            let selected = AppGroupUserDefaults.User.cryptoMarketChangePeriod
            cell.titleLabel.text = R.string.localizable.example_price_change()
            cell.subtitleLabel.text = switch selected {
            case .twentyFourHours:
                R.string.localizable.hour_count(24)
            case .sevenDays:
                R.string.localizable.days_count(7)
            }
            cell.actionButton.menu = UIMenu(children: MarketChangePeriod.allCases.map { period in
                UIAction(
                    title: period.displayTitle,
                    image: nil,
                    state: period == selected ? .on : .off,
                    handler: { [weak self] _ in self?.setPriceChange(period: period) }
                )
            })
        }
        return cell
    }
    
}
