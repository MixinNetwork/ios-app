import UIKit
import MixinServices

final class AlertFrequencySelectorViewController: PopupSelectorViewController {
    
    private let initialSelection: MarketAlert.AlertFrequency
    private let onSelected: (MarketAlert.AlertFrequency) -> Void
    private let frequencies = MarketAlert.AlertFrequency.allCases
    
    init(
        selection: MarketAlert.AlertFrequency,
        onSelected: @escaping (MarketAlert.AlertFrequency) -> Void
    ) {
        self.initialSelection = selection
        self.onSelected = onSelected
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.alert_frequency()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.marketAlertParameterCell)
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        if let row = frequencies.firstIndex(of: initialSelection) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
    }
    
}

extension AlertFrequencySelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        frequencies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_alert_parameter, for: indexPath)!
        let frequency = frequencies[indexPath.row]
        cell.iconImageView.image = frequency.icon
        cell.titleLabel.text = frequency.name
        cell.subtitleLabel.text = frequency.description
        return cell
    }
    
}

extension AlertFrequencySelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let frequency = frequencies[indexPath.row]
        onSelected(frequency)
        presentingViewController?.dismiss(animated: true)
    }
    
}
