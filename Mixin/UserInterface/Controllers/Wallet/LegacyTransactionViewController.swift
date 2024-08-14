import UIKit
import MixinServices

class LegacyTransactionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeaderView: InfiniteTopView!
    @IBOutlet weak var headerContentStackView: UIStackView!
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    private let cellReuseId = "cell"
    
    private var asset: AssetItem!
    private var snapshot: SnapshotItem!
    private var contents: [(title: String, subtitle: String?)]!
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        symbolLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        assetIconView.setIcon(asset: asset)
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        if snapshot.type == SnapshotType.pendingDeposit.rawValue {
            amountLabel.textColor = .walletGray
        } else {
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        }
        amountLabel.setFont(scaledFor: .condensed(size: 34), adjustForContentSize: true)
        fiatMoneyValueLabel.text = R.string.localizable.value_now(Currency.current.symbol + getFormatValue(priceUsd: asset.priceUsd)) + "\n "
        symbolLabel.text = snapshot.assetSymbol
        if ScreenHeight.current >= .extraLong {
            assetIconView.badgeIconDiameter = 28
            assetIconView.badgeOutlineWidth = 4
            headerContentStackView.spacing = 2
        }
        layoutTableHeaderView()
        makeContents()
        tableView.dataSource = self
        tableView.delegate = self
        updateTableViewContentInsetBottom()
        fetchThatTimePrice()
        fetchTransaction()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            DispatchQueue.main.async {
                self.layoutTableHeaderView()
                self.tableView.tableHeaderView = self.tableHeaderView
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:))
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = snapshot.amount
    }
    
    @IBAction func longPressAmountAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        becomeFirstResponder()
        AppDelegate.current.mainWindow.addDismissMenuResponder()
        UIMenuController.shared.showMenu(from: amountLabel, rect: amountLabel.bounds)
    }
    
    class func instance(asset: AssetItem, snapshot: SnapshotItem) -> UIViewController {
        let vc = R.storyboard.wallet.transaction()!
        vc.asset = asset
        vc.snapshot = snapshot
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.transaction())
        return container
    }
    
}

extension LegacyTransactionViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}

extension LegacyTransactionViewController: UITableViewDataSource {
    
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

extension LegacyTransactionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard snapshot.type == SnapshotType.transfer.rawValue, indexPath.row == 3 else {
            return
        }
        guard let userId = snapshot.opponentId, !userId.isEmpty else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId) else {
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
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension LegacyTransactionViewController {
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 20 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 20
        }
    }
    
    private func layoutTableHeaderView() {
        let targetSize = CGSize(width: AppDelegate.current.mainWindow.bounds.width,
                                height: UIView.layoutFittingExpandedSize.height)
        tableHeaderView.frame.size.height = tableHeaderView.systemLayoutSizeFitting(targetSize).height
    }
    
    private func fetchThatTimePrice() {
        AssetAPI.ticker(asset: snapshot.assetId, offset: snapshot.createdAt) { [weak self](result) in
            guard let self = self else {
                return
            }
            switch result {
            case let .success(asset):
                let nowValue = Currency.current.symbol + self.getFormatValue(priceUsd: self.asset.priceUsd)
                let thenValue = asset.priceUsd.doubleValue > 0 ? Currency.current.symbol + self.getFormatValue(priceUsd: asset.priceUsd) : R.string.localizable.na()
                self.fiatMoneyValueLabel.text = R.string.localizable.value_now(nowValue) + "\n" + R.string.localizable.value_then(thenValue)
            case .failure:
                break
            }
        }
    }
    
    private func fetchTransaction() {
        var shouldRefreshSnapshot = snapshot.snapshotHash.isNilOrEmpty
        if snapshot.type == SnapshotType.withdrawal.rawValue && snapshot.transactionHash.isNilOrEmpty {
            shouldRefreshSnapshot = true
        } else if snapshot.type == SnapshotType.pendingDeposit.rawValue {
            let assetId = asset.assetId
            let snapshotId = snapshot.snapshotId
            for entry in asset.depositEntries {
                AssetAPI.pendingDeposits(assetId: assetId, destination: entry.destination, tag: entry.tag) { [weak self](result) in
                    switch result {
                    case let .success(deposits):
                        DispatchQueue.global().async {
                            guard let snapshotItem = SnapshotDAO.shared.replacePendingDeposits(assetId: assetId, pendingDeposits: deposits, snapshotId: snapshotId) else {
                                return
                            }
                            DispatchQueue.main.async {
                                self?.snapshot = snapshotItem
                                self?.makeContents()
                                self?.tableView.reloadData()
                            }
                        }
                    case .failure:
                        break
                    }
                }
            }
        }
        if shouldRefreshSnapshot {
            SnapshotAPI.snapshot(snapshotId: snapshot.snapshotId) { [weak self](result) in
                switch result {
                case let .success(snapshot):
                    DispatchQueue.global().async {
                        guard let snapshotItem = SnapshotDAO.shared.saveSnapshot(snapshot: snapshot) else {
                            return
                        }
                        DispatchQueue.main.async {
                            self?.snapshot = snapshotItem
                            self?.makeContents()
                            self?.tableView.reloadData()
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
    
    private func getFormatValue(priceUsd: String) -> String {
        let fiatMoneyValue = snapshot.amount.doubleValue * priceUsd.doubleValue * Currency.current.rate
        return CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never) ?? ""
    }
    
    private func makeContents() {
        contents = []
        contents.append((title: R.string.localizable.transaction_id(), subtitle: snapshot.snapshotId))
        if let snapshotHash = snapshot.snapshotHash, !snapshotHash.isEmpty {
            contents.append((title: R.string.localizable.snapshot_hash(), subtitle: snapshotHash))
        }
        contents.append((title: R.string.localizable.asset_type(), subtitle: asset.name))
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.pendingDeposit.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.deposit()))
            if snapshot.type == SnapshotType.pendingDeposit.rawValue, let finished = snapshot.confirmations, let total = asset?.confirmations {
                contents.append((title: R.string.localizable.status(), subtitle: R.string.localizable.pending_confirmations(finished, total)))
            }
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            if snapshot.hasSender {
                contents.append((title: R.string.localizable.address(), subtitle: snapshot.sender))
            }
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.transfer.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.transfer()))
            if snapshot.amount.doubleValue > 0 {
                contents.append((title: R.string.localizable.from(), subtitle: snapshot.opponentUserFullName))
            } else {
                contents.append((title: R.string.localizable.to(), subtitle: snapshot.opponentUserFullName))
            }
            if snapshot.hasMemo {
                contents.append((title: R.string.localizable.memo(), subtitle: snapshot.memo))
            }
        case SnapshotType.raw.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.raw()))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            if snapshot.hasSender {
                contents.append((title: R.string.localizable.from(), subtitle: snapshot.sender))
            }
            if snapshot.hasReceiver {
                contents.append((title: R.string.localizable.to(), subtitle: snapshot.receiver))
            }
            if snapshot.hasMemo {
                contents.append((title: R.string.localizable.memo(), subtitle: snapshot.memo))
            }
        case SnapshotType.withdrawal.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.withdrawal()))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.receiver(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.fee.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.fee()))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.receiver(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        case SnapshotType.rebate.rawValue:
            contents.append((title: R.string.localizable.transaction_type(), subtitle: R.string.localizable.rebate()))
            contents.append((title: R.string.localizable.transaction_hash(), subtitle: snapshot.transactionHash))
            contents.append((title: R.string.localizable.receiver(), subtitle: snapshot.receiver))
            if snapshot.hasMemo {
                contents.append((title: asset.memoLabel, subtitle: snapshot.memo))
            }
        default:
            break
        }
        if !snapshot.openingBalance.isEmpty {
            contents.append((title: R.string.localizable.opening_balance(), subtitle: "\(formatedBalance(snapshot.openingBalance)) \(asset.symbol)"))
        }
        if !snapshot.closingBalance.isEmpty {
            contents.append((title: R.string.localizable.closing_balance(), subtitle: "\(formatedBalance(snapshot.closingBalance)) \(asset.symbol)"))
        }
        contents.append((title: R.string.localizable.date(), subtitle: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate())))
    }
    
    private func formatedBalance(_ balance: String) -> String {
        let amount: String
        if balance == "0" {
            amount = zeroWith2Fractions
        } else {
            amount = CurrencyFormatter.localizedString(from: balance, format: .precision, sign: .never) ?? ""
        }
        return amount
    }
    
    private func canCopyAction(indexPath: IndexPath) -> (Bool, String) {
        let title = contents[indexPath.row].title
        let subtitle = contents[indexPath.row].subtitle
        switch title {
        case R.string.localizable.transaction_id(),
             R.string.localizable.transaction_hash(),
             R.string.localizable.memo(),
             asset.memoLabel,
             R.string.localizable.address(),
             R.string.localizable.from(),
             R.string.localizable.to(),
             R.string.localizable.snapshot_hash():
            return (true, subtitle ?? "")
        default:
            return (false, "")
        }
    }
    
}
