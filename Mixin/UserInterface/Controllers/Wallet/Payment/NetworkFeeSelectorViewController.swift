import UIKit
import MixinServices

protocol NetworkFee {
    
    associatedtype T: OnChainToken
    
    var token: T { get }
    var amount: Decimal { get }
    
}

final class NetworkFeeSelectorViewController<Fee: NetworkFee>: PopupSelectorViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let fees: [Fee]
    private let selectedIndex: Int
    private let onSelected: (Int) -> Void

    init(fees: [Fee], selectedIndex: Int, onSelected: @escaping (Int) -> Void) {
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
        tableView.register(R.nib.networkFeeCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        titleView.titleLabel.text = R.string.localizable.network_fee()
        titleView.subtitleLabel.text = R.string.localizable.select_a_token_for_the_fee()
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fees.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.network_fee, for: indexPath)!
        let fee = fees[indexPath.row]
        cell.tokenIconView.setIcon(token: fee.token, chain: fee.token.chain)
        cell.titleLabel.text = fee.token.name + "(" + fee.token.symbol + ")"
        cell.subtitleLabel.text = CurrencyFormatter.localizedString(
            from: fee.amount,
            format: .precision,
            sign: .never,
            symbol: .custom(fee.token.symbol)
        )
        cell.checkmarkImageView.isHidden = indexPath.row != selectedIndex
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelected(indexPath.row)
        close(tableView)
    }
    
}
