import UIKit
import MixinServices

class SnapshotViewController: ColumnListViewController {
    
    @IBOutlet weak var headerContentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    private var token: TokenItem
    private var snapshot: SafeSnapshotItem
    
    init(token: TokenItem, snapshot: SafeSnapshotItem) {
        self.token = token
        self.snapshot = snapshot
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
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
    
    override func deselectRow(column: Column) {
        guard let key = column.key as? SnapshotKey else {
            return
        }
        switch key {
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
        case .memo:
            guard !snapshot.memo.isEmpty, let utf8DecodedMemo = snapshot.utf8DecodedMemo else {
                return
            }
            let memo = MemoViewController(rawMemo: snapshot.memo, utf8DecodedMemo: utf8DecodedMemo)
            present(memo, animated: true, completion: nil)
        default:
            break
        }
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

extension SnapshotViewController {

    enum SnapshotKey: ColumnKey {
        
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
        
        var allowCopy: Bool {
            switch self {
            case .id, .transactionHash, .memo, .from,
                    .to, .depositHash, .withdrawalHash:
                true
            default:
                false
            }
        }
        
    }
    
    class SnapshotColumn: Column {
        
        init(key: SnapshotKey, value: String, style: Column.Style = []) {
            super.init(key: key, value: value, style: style)
        }
        
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
        let type = SafeSnapshot.SnapshotType(rawValue: snapshot.type)
        let needsReloadWithdrawalInfo: Bool
        if type == .withdrawal {
            // All snapshots come from remote are in type of `snapshot`
            // A `withdrawal` typed snapshot indicates that one is made locally
            needsReloadWithdrawalInfo = true
        } else if let withdrawal = snapshot.withdrawal, withdrawal.hash.isEmpty {
            needsReloadWithdrawalInfo = true
        } else {
            needsReloadWithdrawalInfo = false
        }
        if needsReloadWithdrawalInfo {
            SafeAPI.snapshot(with: snapshot.id, queue: .global()) { [weak self] result in
                switch result {
                case let .success(snapshot):
                    self?.reloadData(with: snapshot)
                case .failure:
                    break
                }
            }
        } else if type == .pending {
            Task { [weak self, assetID=token.assetID, snapshotID=snapshot.id] in
                guard let chainID = TokenDAO.shared.chainID(ofAssetWith: assetID) else {
                    return
                }
                var pendingDeposits: [SafePendingDeposit] = []
                let entries = DepositEntryDAO.shared.entries(ofChainWith: chainID)
                for entry in entries {
                    let deposits = try await SafeAPI.deposits(assetID: assetID,
                                                              destination: entry.destination,
                                                              tag: entry.tag)
                    pendingDeposits.append(contentsOf: deposits)
                }
                SafeSnapshotDAO.shared.replacePendingSnapshots(assetID: assetID, pendingDeposits: pendingDeposits)
                
                if let deposit = pendingDeposits.first(where: { $0.id == snapshotID }) {
                    let snapshot = SafeSnapshot(pendingDeposit: deposit)
                    await MainActor.run {
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
        SafeSnapshotDAO.shared.save(snapshot: snapshot) { item in
            guard let item else {
                return
            }
            DispatchQueue.main.async {
                self.snapshot = item
                self.reloadData()
            }
        }
    }
    
    private func reloadData() {
        var columns: [SnapshotColumn] = []
        
        if snapshot.type == SafeSnapshot.SnapshotType.pending.rawValue {
            if let completed = snapshot.confirmations {
                let value = R.string.localizable.pending_confirmations(completed, token.confirmations)
                columns.append(SnapshotColumn(key: .depositProgress, value: value))
            }
        } else {
            columns.append(SnapshotColumn(key: .id, value: snapshot.id))
            columns.append(SnapshotColumn(key: .transactionHash, value: snapshot.transactionHash))
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
            columns.append(SnapshotColumn(key: .from, value: sender, style: style))
            columns.append(SnapshotColumn(key: .depositHash, value: deposit.hash))
        } else if let withdrawal = snapshot.withdrawal {
            let receiver: String
            let receiverStyle: Column.Style
            if withdrawal.receiver.isEmpty {
                receiver = notApplicable
                receiverStyle = .unavailable
            } else {
                receiver = withdrawal.receiver
                receiverStyle = []
            }
            columns.append(SnapshotColumn(key: .to, value: receiver, style: receiverStyle))
            
            let withdrawalHash: String
            let withdrawalStyle: Column.Style
            if withdrawal.hash.isEmpty {
                withdrawalHash = R.string.localizable.withdrawal_pending()
                withdrawalStyle = .unavailable
            } else {
                withdrawalHash = withdrawal.hash
                withdrawalStyle = []
            }
            columns.append(SnapshotColumn(key: .withdrawalHash, value: withdrawalHash, style: withdrawalStyle))
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
                columns.append(SnapshotColumn(key: .to, value: opponentName, style: style))
            } else {
                columns.append(SnapshotColumn(key: .from, value: opponentName, style: style))
            }
        }
        if !snapshot.memo.isEmpty {
            let style: Column.Style
            let value: String
            if let utf8DecodedMemo = snapshot.utf8DecodedMemo {
                style = .disclosureIndicator
                value = utf8DecodedMemo
            } else {
                style = []
                value = snapshot.memo
            }
            columns.append(SnapshotColumn(key: .memo, value: value, style: style))
        }
        columns.append(SnapshotColumn(key: .createdAt, value: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate())))
        self.columns = columns
        tableView.reloadData()
    }
    
}
