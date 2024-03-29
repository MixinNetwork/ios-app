import UIKit
import MixinServices

final class WithdrawFeeSelectorViewController: PopupSelectorViewController {
    
    private let fees: [WithdrawFeeItem]
    private let selectedIndex: Int
    private let onSelected: (Int) -> Void

    init(fees: [WithdrawFeeItem], selectedIndex: Int, onSelected: @escaping (Int) -> Void) {
        self.fees = fees
        self.selectedIndex = selectedIndex
        self.onSelected = onSelected
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 72
        tableView.register(R.nib.withdrawFeeCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        titleView.titleLabel.text = R.string.localizable.network_fee()
        titleView.subtitleLabel.text = R.string.localizable.select_a_token_for_the_fee()
    }
    
}

extension WithdrawFeeSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.withdraw_fee, for: indexPath)!
        let fee = fees[indexPath.row]
        cell.tokenIconView.setIcon(token: fee.tokenItem)
        cell.titleLabel.text = fee.tokenItem.name + "(" + fee.tokenItem.symbol + ")"
        cell.subtitleLabel.text = CurrencyFormatter.localizedString(from: fee.amount, format: .precision, sign: .never, symbol: .custom(fee.tokenItem.symbol))
        cell.checkmarkImageView.isHidden = indexPath.row != selectedIndex
        return cell
    }
    
}

extension WithdrawFeeSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelected(indexPath.row)
        close(tableView)
    }
    
}
