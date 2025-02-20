import UIKit
import MixinServices

final class SafeSnapshotViewController: RowListViewController {
    
    @IBOutlet weak var headerContentStackView: UIStackView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    @IBOutlet weak var iconViewDimensionConstraint: ScreenHeightCompatibleLayoutConstraint!
    
    private let messageID: String?
    
    private var token: TokenItem
    private var snapshot: SafeSnapshotItem
    private var inscription: InscriptionItem?
    
    init(token: TokenItem, snapshot: SafeSnapshotItem, messageID: String?, inscription: InscriptionItem?) {
        self.token = token
        self.snapshot = snapshot
        self.messageID = messageID
        self.inscription = inscription
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.transaction()
        tableHeaderView = R.nib.snapshotTableHeaderView(withOwner: self)
        tableView.tableHeaderView = tableHeaderView
        amountLabel.setFont(scaledFor: .condensed(size: 34), adjustForContentSize: true)
        symbolLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        if snapshot.isInscription {
            if let inscription {
                iconView.setIcon(content: inscription)
                switch inscription.inscriptionContent {
                case .image, .none:
                    break
                case let .text(collectionIconURL, textContentURL):
                    let dimension = round(iconViewDimensionConstraint.constant / 70 * 40)
                    let textContentView = TextInscriptionContentView(iconDimension: dimension, spacing: 4)
                    textContentView.label.numberOfLines = 1
                    textContentView.label.font = .systemFont(ofSize: 8, weight: .semibold)
                    tableHeaderView.addSubview(textContentView)
                    textContentView.snp.makeConstraints { make in
                        make.top.greaterThanOrEqualTo(iconView).offset(8)
                        make.leading.equalTo(iconView).offset(15)
                        make.trailing.equalTo(iconView).offset(-15)
                        make.bottom.lessThanOrEqualTo(iconView).offset(-8)
                        make.centerY.equalTo(iconView)
                    }
                    textContentView.reloadData(collectionIconURL: collectionIconURL,
                                               textContentURL: textContentURL)
                }
            } else {
                iconView.setIcon(content: snapshot)
            }
            let amount: Decimal = snapshot.decimalAmount > 0 ? 1 : -1
            amountLabel.text = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .always)
            symbolLabel.text = nil
            fiatMoneyValueLabel.text = nil
        } else {
            iconView.setIcon(token: token)
            amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.decimalAmount, format: .precision, sign: .always)
            symbolLabel.text = token.symbol
            fiatMoneyValueLabel.text = R.string.localizable.value_now(Currency.current.symbol + fiatMoneyValue(usdPrice: token.decimalUSDPrice)) + "\n "
        }
        if ScreenHeight.current >= .extraLong {
            iconView.badgeIconDiameter = 28
            iconView.badgeOutlineWidth = 4
            headerContentStackView.spacing = 2
        }
        updateAmountLabelColor()
        layoutTableHeaderView()
        
        reloadRows()
        updateTableViewContentInsetBottom()
        if let hash = snapshot.inscriptionHash {
            if inscription == nil {
                let job = RefreshInscriptionJob(inscriptionHash: hash)
                job.messageID = messageID
                job.snapshotID = snapshot.id
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(reloadInscription(_:)),
                                                       name: RefreshInscriptionJob.didFinishNotification,
                                                       object: job)
                ConcurrentJobQueue.shared.addJob(job: job)
            }
            iconView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(revealInscription(_:))))
        } else {
            AssetAPI.ticker(asset: snapshot.assetID, offset: snapshot.createdAt) { [weak self] (result) in
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
            iconView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(revealToken(_:))))
        }
        reloadSnapshotIfNeeded()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        switch rows[indexPath.row].key as? SnapshotKey {
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
    
    @IBAction func longPressAmountAction(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        becomeFirstResponder()
        AppDelegate.current.mainWindow.addDismissMenuResponder()
        UIMenuController.shared.showMenu(from: amountLabel, rect: amountLabel.bounds)
    }
    
    @objc private func revealToken(_ recognizer: UITapGestureRecognizer) {
        guard let viewControllers = navigationController?.viewControllers else {
            return
        }
        if let viewController = viewControllers
            .compactMap({ $0 as? TokenViewController })
            .first(where: { $0.token.assetID == token.assetID })
        {
            navigationController?.popToViewController(viewController, animated: true)
        } else {
            let viewController = TokenViewController(token: token)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    @objc private func revealInscription(_ recognizer: UITapGestureRecognizer) {
        guard let inscription else {
            return
        }
        let preview: InscriptionViewController
        if let output = InscriptionDAO.shared.inscriptionOutput(inscriptionHash: inscription.inscriptionHash) {
            preview = InscriptionViewController(output: output)
        } else {
            preview = InscriptionViewController(inscription: inscription)
        }
        navigationController?.pushViewController(preview, animated: true)
    }
    
    @objc private func reloadInscription(_ notification: Notification) {
        guard let item = notification.userInfo?[RefreshInscriptionJob.UserInfoKey.item] as? InscriptionItem else {
            return
        }
        self.inscription = item
        iconView.setIcon(content: item)
        reloadRows()
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(copy(_:))
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = snapshot.amount
    }
    
}

extension SafeSnapshotViewController {
    
    enum SnapshotKey: RowKey {
        
        case transactionID
        case transactionHash
        case from
        case to
        case depositHash
        case withdrawalHash
        case inscriptionHash
        case collectionName
        case id
        case depositProgress
        case createdAt
        case memo
        
        var localized: String {
            switch self {
            case .transactionID:
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
            case .inscriptionHash:
                return R.string.localizable.collectible_hash()
            case .collectionName:
                return R.string.localizable.collection()
            case .id:
                return R.string.localizable.id()
            case .depositProgress:
                return R.string.localizable.status()
            case .createdAt:
                return R.string.localizable.date()
            case .memo:
                return R.string.localizable.memo()
            }
        }
        
        var allowsCopy: Bool {
            switch self {
            case .transactionID, .transactionHash,
                    .memo, .from, .to, .depositHash,
                    .withdrawalHash, .inscriptionHash:
                true
            default:
                false
            }
        }
        
    }
    
    class SnapshotRow: Row {
        
        init(key: SnapshotKey, value: String, style: Row.Style = []) {
            super.init(key: key, value: value, style: style)
        }
        
    }
    
}

extension SafeSnapshotViewController {
    
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
                guard let chainID = TokenDAO.shared.chainID(assetID: assetID) else {
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
                self.updateAmountLabelColor()
                self.reloadRows()
            }
        }
    }
    
    private func updateAmountLabelColor() {
        switch SafeSnapshot.SnapshotType(rawValue: snapshot.type) {
        case .pending:
            amountLabel.textColor = R.color.text_tertiary()!
        default:
            if let withdrawal = snapshot.withdrawal, withdrawal.hash.isEmpty {
                amountLabel.textColor = R.color.text_tertiary()!
            } else if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = R.color.market_red()
            } else {
                amountLabel.textColor = R.color.market_green()
            }
        }
    }
    
    private func reloadRows() {
        var rows: [SnapshotRow] = []
        
        if snapshot.type == SafeSnapshot.SnapshotType.pending.rawValue {
            if let completed = snapshot.confirmations {
                let value = R.string.localizable.pending_confirmations(completed, token.confirmations)
                rows.append(SnapshotRow(key: .depositProgress, value: value))
            }
        } else {
            rows.append(SnapshotRow(key: .transactionID, value: snapshot.id))
            rows.append(SnapshotRow(key: .transactionHash, value: snapshot.transactionHash))
        }
        
        if let deposit = snapshot.deposit {
            let style: Row.Style
            let sender: String
            if deposit.sender.isEmpty {
                sender = notApplicable
                style = .unavailable
            } else {
                sender = deposit.sender
                style = []
            }
            rows.append(SnapshotRow(key: .from, value: sender, style: style))
            rows.append(SnapshotRow(key: .depositHash, value: deposit.hash))
        } else if let withdrawal = snapshot.withdrawal {
            let receiver: String
            let receiverStyle: Row.Style
            if withdrawal.receiver.isEmpty {
                receiver = notApplicable
                receiverStyle = .unavailable
            } else {
                receiver = withdrawal.receiver
                receiverStyle = []
            }
            rows.append(SnapshotRow(key: .to, value: receiver, style: receiverStyle))
            
            let withdrawalHash: String
            let withdrawalStyle: Row.Style
            if withdrawal.hash.isEmpty {
                withdrawalHash = R.string.localizable.withdrawal_pending()
                withdrawalStyle = .unavailable
            } else {
                withdrawalHash = withdrawal.hash
                withdrawalStyle = []
            }
            rows.append(SnapshotRow(key: .withdrawalHash, value: withdrawalHash, style: withdrawalStyle))
        } else {
            if let inscriptionHash = snapshot.inscriptionHash {
                rows.append(SnapshotRow(key: .inscriptionHash, value: inscriptionHash))
                if let inscription = inscription {
                    rows.append(SnapshotRow(key: .collectionName, value: inscription.collectionName))
                    rows.append(SnapshotRow(key: .id, value: inscription.sequenceRepresentation))
                }
            }
            let style: Row.Style
            let opponentName: String
            if let name = snapshot.opponentFullname {
                opponentName = name
                style = []
            } else {
                opponentName = notApplicable
                style = .unavailable
            }
            if snapshot.amount.hasMinusPrefix {
                rows.append(SnapshotRow(key: .to, value: opponentName, style: style))
            } else {
                rows.append(SnapshotRow(key: .from, value: opponentName, style: style))
            }
        }
        if !snapshot.memo.isEmpty {
            let style: Row.Style
            let value: String
            if let utf8DecodedMemo = snapshot.utf8DecodedMemo {
                style = .disclosureIndicator
                value = utf8DecodedMemo
            } else {
                style = []
                value = snapshot.memo
            }
            rows.append(SnapshotRow(key: .memo, value: value, style: style))
        }
        rows.append(SnapshotRow(key: .createdAt, value: DateFormatter.dateFull.string(from: snapshot.createdAt.toUTCDate())))
        self.rows = rows
        tableView.reloadData()
    }
    
}
