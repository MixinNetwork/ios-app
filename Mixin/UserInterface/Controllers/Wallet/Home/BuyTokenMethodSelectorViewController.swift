import UIKit
import MixinServices

final class BuyTokenMethodSelectorViewController: PopupSelectorViewController, UITableViewDataSource, UITableViewDelegate {
    
    enum Method {
        case card
        case bankTransfer
    }
    
    var onSelected: ((Method) -> Void)?
    
    private let methods: [Method] = [.card, .bankTransfer]
    
    private var cashAccount: CashAccount?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_quaternary()
        titleView.backgroundColor = R.color.background_quaternary()
        titleView.titleStackView.alignment = .leading
        titleView.titleLabel.text = R.string.localizable.buy()
        let subtitleLabel = UILabel()
        subtitleLabel.textColor = R.color.text_quaternary()
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.text = R.string.localizable.privacy_wallet()
        let walletImageView = UIImageView(image: R.image.privacy_wallet())
        let subtitleView = UIStackView(arrangedSubviews: [subtitleLabel, walletImageView])
        subtitleView.alignment = .center
        subtitleView.axis = .horizontal
        subtitleView.spacing = 4
        titleView.titleStackView.addArrangedSubview(subtitleView)
        walletImageView.snp.makeConstraints { make in
            make.width.height.equalTo(16)
        }
        tableView.backgroundColor = R.color.background_quaternary()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 95
        tableView.register(R.nib.buyTokenMethodCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        DispatchQueue.global().async {
            let cashAccount = PropertiesDAO.shared.jsonObject(
                forKey: .cashAccount,
                type: CashAccount.self
            )
            DispatchQueue.main.async {
                self.cashAccount = cashAccount
                self.tableView.reloadData()
            }
        }
    }
    
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        tableView.contentInset.bottom = 40 + view.safeAreaInsets.bottom
        updatePreferredContentHeight()
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        methods.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.buy_token_method, for: indexPath)!
        switch methods[indexPath.row] {
        case .card:
            cell.iconImageView.image = R.image.buy_token_card()
            cell.titleLabel.text = R.string.localizable.wallet_buy_option_apple_pay_or_card()
            cell.subtitleLabel.text = R.string.localizable.wallet_buy_option_apple_pay_or_card_desc()
            cell.apyLabel.isHidden = true
        case .bankTransfer:
            cell.iconImageView.image = R.image.buy_token_bank()
            cell.titleLabel.text = R.string.localizable.wallet_buy_option_bank_transfer()
            cell.subtitleLabel.text = R.string.localizable.wallet_buy_option_bank_transfer_desc()
            if let apy = cashAccount?.displayAPY {
                cell.apyLabel.text = apy
                cell.apyLabel.isHidden = false
            } else {
                cell.apyLabel.isHidden = true
            }
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelected?(methods[indexPath.row])
        close(tableView)
    }
    
}
