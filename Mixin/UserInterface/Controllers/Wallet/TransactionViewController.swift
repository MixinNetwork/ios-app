import UIKit
import MixinServices

class TransactionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerContentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    private let cellReuseId = "cell"
    
    private var asset: AssetItem!
    private var snapshot: SnapshotItem!
    private var contents: [(title: String, subtitle: String?)]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if ScreenHeight.current >= .extraLong {
            assetIconView.chainIconWidth = 28
            assetIconView.chainIconOutlineWidth = 4
            tableView.tableHeaderView?.frame.size.height = 210
            headerContentStackView.spacing = 5
        }
        view.layoutIfNeeded()
        symbolLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        assetIconView.setIcon(asset: asset)
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.decimalAmount, format: .precision, sign: .always)
        if snapshot.type == SnapshotType.pendingDeposit.rawValue {
            amountLabel.textColor = .walletGray
        } else {
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        }
        amountLabel.setFont(scaledFor: .dinCondensedBold(ofSize: 34), adjustForContentSize: true)
        fiatMoneyValueLabel.text = R.string.localizable.transaction_value_now(localizedFiatMoneyValue(usdPrice: asset.decimalUSDPrice))
        symbolLabel.text = snapshot.assetSymbol
        makeContents()
        tableView.dataSource = self
        tableView.delegate = self
        updateTableViewContentInsetBottom()
        fetchThatTimePrice()
    }
    
    private func fetchThatTimePrice() {
        AssetAPI.ticker(asset: snapshot.assetId, offset: snapshot.createdAt) { [weak self](result) in
            guard let self = self else {
                return
            }
            switch result {
            case let .success(asset):
                let nowValue = self.localizedFiatMoneyValue(usdPrice: self.asset.decimalUSDPrice)
                let thenValue = self.localizedFiatMoneyValue(usdPrice: asset.decimalUSDPrice)
                self.fiatMoneyValueLabel.text = R.string.localizable.transaction_value_now(nowValue)
                    + "\n"
                    + R.string.localizable.transaction_value_then(thenValue)
            case .failure:
                break
            }
        }
    }
    
    private func localizedFiatMoneyValue(usdPrice: Decimal) -> String {
        let fiatMoneyValue = snapshot.decimalAmount * usdPrice * Currency.current.decimalRate
        return Currency.current.symbol + CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never)
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    class func instance(asset: AssetItem, snapshot: SnapshotItem) -> UIViewController {
        let vc = R.storyboard.wallet.transaction()!
        vc.asset = asset
        vc.snapshot = snapshot
        let container = ContainerViewController.instance(viewController: vc, title: Localized.TRANSACTION_TITLE)
        return container
    }
    
}

extension TransactionViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}

extension TransactionViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! TransactionCell
        cell.titleLabel.text = contents[indexPath.row].title
        cell.subtitleLabel.text = contents[indexPath.row].subtitle
        return cell
    }
    
}

extension TransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard snapshot.type == SnapshotType.transfer.rawValue, indexPath.row == 3 else {
            return
        }
        guard let userId = snapshot.opponentId, !userId.isEmpty else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId), user.isCreatedByMessenger else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return canCopyAction(indexPath: indexPath).0
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return canCopyAction(indexPath: indexPath).0 && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        let copy: (can: Bool, body: String) = canCopyAction(indexPath: indexPath)
        guard copy.can else {
            return
        }
        UIPasteboard.general.string = copy.body
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_COPIED)
    }
    
}

extension TransactionViewController {
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 20 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 20
        }
    }
    
    private func makeContents() {
        contents = []
        contents.append((title: Localized.TRANSACTION_ID, subtitle: snapshot.snapshotId))
        contents.append((title: Localized.TRANSACTION_ASSET, subtitle: asset.name))
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.pendingDeposit.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle: Localized.TRANSACTION_TYPE_DEPOSIT))
            if snapshot.type == SnapshotType.pendingDeposit.rawValue, let finished = snapshot.confirmations, let total = asset?.confirmations {
                contents.append((title: R.string.localizable.transaction_status(), subtitle: Localized.PENDING_DEPOSIT_CONFIRMATION(numerator: finished,
                denominator: total)))
            }
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            if snapshot.hasSender {
                contents.append((title: R.string.localizable.wallet_address_destination(), subtitle: snapshot.sender))
            }
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.transfer.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle: Localized.TRANSACTION_TYPE_TRANSFER))
            if snapshot.decimalAmount > 0 {
                contents.append((title: R.string.localizable.wallet_snapshot_transfer_from(), subtitle: snapshot.opponentUserFullName))
            } else {
                contents.append((title: R.string.localizable.wallet_snapshot_transfer_to(), subtitle: snapshot.opponentUserFullName))
            }
            if snapshot.hasMemo {
                contents.append((title: Localized.TRANSACTION_MEMO, subtitle: snapshot.memo))
            }
        case SnapshotType.raw.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle: R.string.localizable.transaction_type_raw()))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            if snapshot.hasSender {
                contents.append((title: R.string.localizable.wallet_snapshot_transfer_from(), subtitle: snapshot.sender))
            }
            if snapshot.hasReceiver {
                contents.append((title: R.string.localizable.wallet_snapshot_transfer_to(), subtitle: snapshot.receiver))
            }
            if snapshot.hasMemo {
                contents.append((title: Localized.TRANSACTION_MEMO, subtitle: snapshot.memo))
            }
        case SnapshotType.withdrawal.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle:
                Localized.TRANSACTION_TYPE_WITHDRAWAL))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.wallet_address_destination(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.fee.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle: Localized.TRANSACTION_TYPE_FEE))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.wallet_address_destination(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.rebate.rawValue:
            contents.append((title: Localized.TRANSACTION_TYPE, subtitle: Localized.TRANSACTION_TYPE_REBATE))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.wallet_address_destination(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        default:
            break
        }
        contents.append((title: Localized.TRANSACTION_DATE, subtitle: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate())))
    }
    
    private func canCopyAction(indexPath: IndexPath) -> (Bool, String) {
        let title = contents[indexPath.row].title
        let subtitle = contents[indexPath.row].subtitle
        switch title {
        case R.string.localizable.transaction_id(),
             R.string.localizable.transaction_hash(),
             R.string.localizable.transaction_memo(),
             asset.memoLabel,
             R.string.localizable.wallet_address_destination(),
             R.string.localizable.wallet_snapshot_transfer_from(),
             R.string.localizable.wallet_snapshot_transfer_to():
            return (true, subtitle ?? "")
        default:
            return (false, "")
        }
    }
    
}
