import UIKit
import MixinServices

final class AlertTypeSelectorViewController: PopupSelectorViewController {
    
    private let initialSelection: MarketAlert.AlertType
    private let onSelected: (MarketAlert.AlertType) -> Void
    private let types = MarketAlert.AlertType.allCases
    
    init(
        selected: MarketAlert.AlertType,
        onSelected: @escaping (MarketAlert.AlertType) -> Void
    ) {
        self.initialSelection = selected
        self.onSelected = onSelected
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.alert_type()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.marketAlertParameterCell)
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        if let row = types.firstIndex(of: initialSelection) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
    }
    
}

extension AlertTypeSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        types.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_alert_parameter, for: indexPath)!
        let type = types[indexPath.row]
        cell.iconImageView.image = type.displayType.icon
        switch type.displayType {
        case .constant:
            cell.iconImageView.tintColor = R.color.theme()
        case .increasing:
            cell.iconImageView.marketColor = .rising
        case .decreasing:
            cell.iconImageView.marketColor = .falling
        }
        cell.titleLabel.text = type.name
        cell.subtitleLabel.text = type.description
        return cell
    }
    
}

extension AlertTypeSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = types[indexPath.row]
        onSelected(type)
        presentingViewController?.dismiss(animated: true)
    }
    
}
