import UIKit
import MixinServices

class SnapshotViewController: UIViewController {
    
    let tableView = UITableView()
    var tableHeaderView: InfiniteTopView!
    
    @IBOutlet weak var headerContentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    private var token: TokenItem
    private var snapshot: SafeSnapshotItem
    private var columns: [Column] = []
    
    init(token: TokenItem, snapshot: SafeSnapshotItem) {
        self.token = token
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func loadView() {
        self.view = tableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView = R.nib.snapshotTableHeaderView(withOwner: self)
        symbolLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        assetIconView.setIcon(token: token)
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
        fiatMoneyValueLabel.text = R.string.localizable.value_now(Currency.current.symbol + getFormatValue(priceUsd: token.priceUsd)) + "\n "
        symbolLabel.text = token.symbol
        if ScreenHeight.current >= .extraLong {
            assetIconView.chainIconWidth = 28
            assetIconView.chainIconOutlineWidth = 4
            headerContentStackView.spacing = 2
        }
        layoutTableHeaderView()
        makeContents()
        tableView.backgroundColor = .background
        tableView.register(R.nib.snapshotColumnCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        updateTableViewContentInsetBottom()
        fetchThatTimePrice()
        fetchTransaction()
        
        assetIconView.isUserInteractionEnabled = true
        assetIconView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backToAsset(_:))))
    }
    
    @objc func backToAsset(_ recognizer: UITapGestureRecognizer) {
//        guard let viewControllers = navigationController?.viewControllers else {
//            return
//        }
//
//        if let assetViewController = viewControllers
//            .compactMap({ $0 as? ContainerViewController })
//            .compactMap({ $0.viewController as? AssetViewController })
//            .first(where: { $0.token.assetId == token.assetId })?.container {
//            navigationController?.popToViewController(assetViewController, animated: true)
//        } else {
//            navigationController?.pushViewController(AssetViewController.instance(asset: asset), animated: true)
//        }
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
    
    class func instance(token: TokenItem, snapshot: SafeSnapshotItem) -> UIViewController {
        let snapshot = SnapshotViewController(token: token, snapshot: snapshot)
        let container = ContainerViewController.instance(viewController: snapshot, title: R.string.localizable.transaction())
        return container
    }
    
}

extension SnapshotViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
}

extension SnapshotViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return columns.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot_column, for: indexPath)!
        cell.titleLabel.text = columns[indexPath.row].title
        cell.subtitleLabel.text = columns[indexPath.row].subtitle
        return cell
    }
    
}

extension SnapshotViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
//        guard snapshot.type == SnapshotType.transfer.rawValue, indexPath.row == 3 else {
//            return
//        }
//        guard let userId = snapshot.opponentId, !userId.isEmpty else {
//            return
//        }
//        DispatchQueue.global().async {
//            guard let user = UserDAO.shared.getUser(userId: userId) else {
//                return
//            }
//            DispatchQueue.main.async { [weak self] in
//                let vc = UserProfileViewController(user: user)
//                self?.present(vc, animated: true, completion: nil)
//            }
//        }
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

extension SnapshotViewController {
    
    private struct Column {
        let title: String
        let subtitle: String
    }
    
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
//        AssetAPI.ticker(asset: snapshot.assetId, offset: snapshot.createdAt) { [weak self](result) in
//            guard let self = self else {
//                return
//            }
//            switch result {
//            case let .success(asset):
//                let nowValue = Currency.current.symbol + self.getFormatValue(priceUsd: self.token.priceUsd)
//                let thenValue = token.priceUsd.doubleValue > 0 ? Currency.current.symbol + self.getFormatValue(priceUsd: token.priceUsd) : R.string.localizable.na()
//                self.fiatMoneyValueLabel.text = R.string.localizable.value_now(nowValue) + "\n" + R.string.localizable.value_then(thenValue)
//            case .failure:
//                break
//            }
//        }
    }
    
    private func fetchTransaction() {
//        var shouldRefreshSnapshot = snapshot.snapshotHash.isNilOrEmpty
//        if snapshot.type == SnapshotType.withdrawal.rawValue && snapshot.transactionHash.isNilOrEmpty {
//            shouldRefreshSnapshot = true
//        } else if snapshot.type == SnapshotType.pendingDeposit.rawValue {
//            let assetId = token.assetId
//            let snapshotId = snapshot.snapshotId
//            for entry in token.depositEntries {
//                AssetAPI.pendingDeposits(assetId: assetId, destination: entry.destination, tag: entry.tag) { [weak self](result) in
//                    switch result {
//                    case let .success(deposits):
//                        DispatchQueue.global().async {
//                            guard let snapshotItem = SnapshotDAO.shared.replacePendingDeposits(assetId: assetId, pendingDeposits: deposits, snapshotId: snapshotId) else {
//                                return
//                            }
//                            DispatchQueue.main.async {
//                                self?.snapshot = snapshotItem
//                                self?.makeContents()
//                                self?.tableView.reloadData()
//                            }
//                        }
//                    case .failure:
//                        break
//                    }
//                }
//            }
//        }
//        if shouldRefreshSnapshot {
//            SnapshotAPI.snapshot(snapshotId: snapshot.snapshotId) { [weak self](result) in
//                switch result {
//                case let .success(snapshot):
//                    DispatchQueue.global().async {
//                        guard let snapshotItem = SnapshotDAO.shared.saveSnapshot(snapshot: snapshot) else {
//                            return
//                        }
//                        DispatchQueue.main.async {
//                            self?.snapshot = snapshotItem
//                            self?.makeContents()
//                            self?.tableView.reloadData()
//                        }
//                    }
//                case .failure:
//                    break
//                }
//            }
//        }
    }
    
    private func getFormatValue(priceUsd: String) -> String {
        let fiatMoneyValue = snapshot.amount.doubleValue * priceUsd.doubleValue * Currency.current.rate
        return CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never) ?? ""
    }
    
    private func makeContents() {
        var columns = [
            Column(title: R.string.localizable.transaction_id(), subtitle: snapshot.id),
            Column(title: R.string.localizable.snapshot_hash(), subtitle: snapshot.transactionHash),
            Column(title: R.string.localizable.asset_type(), subtitle: token.name),
        ]
        if !snapshot.memo.isEmpty {
            columns.append(Column(title: R.string.localizable.memo(), subtitle: snapshot.memo))
        }
        columns.append(Column(title: R.string.localizable.date(), subtitle: DateFormatter.dateFull.string(from: snapshot.createdAt)))
        self.columns = columns
    }
    
    private func formatedBalance(_ balance: String) -> String {
        let amount: String
        if balance == "0" {
            amount = "0\(currentDecimalSeparator)00"
        } else {
            amount = CurrencyFormatter.localizedString(from: balance, format: .precision, sign: .never) ?? ""
        }
        return amount
    }
    
    private func canCopyAction(indexPath: IndexPath) -> (Bool, String) {
        let title = columns[indexPath.row].title
        let subtitle = columns[indexPath.row].subtitle
        switch title {
        case R.string.localizable.transaction_id(),
             R.string.localizable.transaction_hash(),
             R.string.localizable.memo(),
             token.memoLabel,
             R.string.localizable.address(),
             R.string.localizable.from(),
             R.string.localizable.to(),
             R.string.localizable.snapshot_hash():
            return (true, subtitle)
        default:
            return (false, "")
        }
    }
    
}
