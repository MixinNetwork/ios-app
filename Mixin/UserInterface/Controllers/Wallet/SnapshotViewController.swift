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
        tableView.tableHeaderView = tableHeaderView
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
        fiatMoneyValueLabel.text = R.string.localizable.value_now(Currency.current.symbol + fiatMoneyValue(usdPrice: token.decimalUSDPrice)) + "\n "
        symbolLabel.text = token.symbol
        if ScreenHeight.current >= .extraLong {
            assetIconView.chainIconWidth = 28
            assetIconView.chainIconOutlineWidth = 4
            headerContentStackView.spacing = 2
        }
        layoutTableHeaderView()
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        tableView.register(R.nib.snapshotColumnCell)
        tableView.dataSource = self
        tableView.delegate = self
        reloadData()
        updateTableViewContentInsetBottom()
        reloadPrices()
        reloadSnapshotIfNeeded()
        
        assetIconView.isUserInteractionEnabled = true
        assetIconView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backToAsset(_:))))
    }
    
    @objc func backToAsset(_ recognizer: UITapGestureRecognizer) {
        guard let viewControllers = navigationController?.viewControllers else {
            return
        }
        if let viewController = viewControllers
            .compactMap({ $0 as? ContainerViewController })
            .compactMap({ $0.viewController as? TokenViewController })
            .first(where: { $0.token.assetID == token.assetID })?.container
        {
            navigationController?.popToViewController(viewController, animated: true)
        } else {
            let viewController = TokenViewController.instance(token: token)
            navigationController?.pushViewController(viewController, animated: true)
        }
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
        let column = columns[indexPath.row]
        cell.titleLabel.text = column.key.localized
        cell.subtitleLabel.text = column.value
        if column.style.contains(.unavailable) {
            cell.subtitleLabel.textColor = R.color.text_accessory()
        } else {
            cell.subtitleLabel.textColor = R.color.text()
        }
        return cell
    }
    
}

extension SnapshotViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch columns[indexPath.row].key {
        case .from, .to:
            guard let id = snapshot.opponentUserID, !id.isEmpty else {
                return
            }
            DispatchQueue.global().async {
                guard let user = UserDAO.shared.getUser(userId: id) else {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    let profile = UserProfileViewController(user: user)
                    self?.present(profile, animated: true, completion: nil)
                }
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        columns[indexPath.row].allowsCopy
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        columns[indexPath.row].allowsCopy && action == #selector(copy(_:))
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        UIPasteboard.general.string = columns[indexPath.row].value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension SnapshotViewController {
    
    private struct Column {
        
        enum Key {
            
            case id
            case transactionHash
            case from
            case to
            case depositHash
            case withdrawalHash
            case depositProgress
            case createdAt
            case memo
            
            var localized: String {
                switch self {
                case .id:
                    return R.string.localizable.transaction_id()
                case .transactionHash:
                    return R.string.localizable.transaction_hash()
                case .from:
                    return R.string.localizable.from()
                case .to:
                    return R.string.localizable.to()
                case .depositHash:
                    return R.string.localizable.deposit_hash()
                case .withdrawalHash:
                    return R.string.localizable.withdrawal_hash()
                case .depositProgress:
                    return R.string.localizable.status()
                case .createdAt:
                    return R.string.localizable.date()
                case .memo:
                    return R.string.localizable.memo()
                }
            }
            
        }
        
        struct Style: OptionSet {
            
            let rawValue: Int
            
            static let unavailable = Style(rawValue: 1 << 0)
            
        }
        
        let key: Key
        let value: String
        let style: Style
        
        var allowsCopy: Bool {
            switch key {
            case .id, .transactionHash, .memo, .from, .to:
                return true
            default:
                return false
            }
        }
        
        init(key: Key, value: String, style: Style = []) {
            self.key = key
            self.value = value
            self.style = style
        }
        
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
    
    private func reloadPrices() {
        AssetAPI.ticker(asset: snapshot.assetID, offset: snapshot.createdAt) { [weak self](result) in
            guard let self = self else {
                return
            }
            switch result {
            case var .success(ticker):
                let nowValue = Currency.current.symbol + self.fiatMoneyValue(usdPrice: self.token.decimalUSDPrice)
                let thenValue = token.decimalUSDPrice > 0 ? Currency.current.symbol + self.fiatMoneyValue(usdPrice: ticker.decimalUSDPrice) : R.string.localizable.na()
                self.fiatMoneyValueLabel.text = R.string.localizable.value_now(nowValue) + "\n" + R.string.localizable.value_then(thenValue)
            case .failure:
                break
            }
        }
    }
    
    private func reloadSnapshotIfNeeded() {
        if let withdrawal = snapshot.withdrawal, withdrawal.hash.isEmpty {
            SafeAPI.snapshot(with: snapshot.id, queue: .global()) { [weak self] result in
                switch result {
                case let .success(snapshot):
                    self?.reloadData(with: snapshot)
                case .failure:
                    break
                }
            }
        } else if snapshot.type == SafeSnapshot.SnapshotType.pending.rawValue {
            Task { [weak self, assetID=token.assetID, snapshotID=snapshot.id] in
                guard let chainID = TokenDAO.shared.chainID(ofAssetWith: assetID) else {
                    return
                }
                let entries = DepositEntryDAO.shared.entries(ofChainWith: chainID)
                for entry in entries {
                    let deposits = try await SafeAPI.deposits(assetID: assetID,
                                                              destination: entry.destination,
                                                              tag: entry.tag)
                    SafeSnapshotDAO.shared.saveSnapshots(with: assetID, pendingDeposits: deposits)
                    if let deposit = deposits.first(where: { $0.id == snapshotID }) {
                        let snapshot = SafeSnapshot(assetID: assetID, pendingDeposit: deposit)
                        self?.reloadData(with: snapshot)
                    }
                }
            }
        }
    }
    
    private func fiatMoneyValue(usdPrice: Decimal) -> String {
        let value = snapshot.decimalAmount * usdPrice * Decimal(Currency.current.rate)
        return CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never)
    }
    
    private func reloadData(with snapshot: SafeSnapshot) {
        guard let item = SafeSnapshotDAO.shared.saveAndFetch(snapshot: snapshot) else {
            return
        }
        DispatchQueue.main.async {
            self.snapshot = item
            self.reloadData()
        }
    }
    
    private func reloadData() {
        var columns: [Column] = []
        
        if snapshot.type == SafeSnapshot.SnapshotType.pending.rawValue {
            if let completed = snapshot.confirmations {
                let value = R.string.localizable.pending_confirmations(completed, token.confirmations)
                columns.append(Column(key: .depositProgress, value: value))
            }
        } else {
            columns.append(Column(key: .id, value: snapshot.id))
            columns.append(Column(key: .transactionHash, value: snapshot.transactionHash))
        }
        
        if let deposit = snapshot.deposit {
            let style: Column.Style
            let sender: String
            if deposit.sender.isEmpty {
                sender = notApplicable
                style = .unavailable
            } else {
                sender = deposit.sender
                style = []
            }
            columns.append(Column(key: .from, value: sender, style: style))
            columns.append(Column(key: .depositHash, value: deposit.hash))
        } else if let withdrawal = snapshot.withdrawal {
            let style: Column.Style
            let receiver: String
            if withdrawal.receiver.isEmpty {
                receiver = notApplicable
                style = .unavailable
            } else {
                receiver = withdrawal.receiver
                style = []
            }
            columns.append(Column(key: .to, value: receiver, style: style))
            columns.append(Column(key: .withdrawalHash, value: withdrawal.hash))
        } else {
            let style: Column.Style
            let opponentName: String
            if let name = snapshot.opponentFullname {
                opponentName = name
                style = []
            } else {
                opponentName = notApplicable
                style = .unavailable
            }
            if snapshot.amount.hasMinusPrefix {
                columns.append(Column(key: .to, value: opponentName, style: style))
            } else {
                columns.append(Column(key: .from, value: opponentName, style: style))
            }
        }
        if !snapshot.memo.isEmpty {
            columns.append(Column(key: .memo, value: snapshot.formattedMemo))
        }
        columns.append(Column(key: .createdAt, value: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate())))
        self.columns = columns
        tableView.reloadData()
    }
    
}
