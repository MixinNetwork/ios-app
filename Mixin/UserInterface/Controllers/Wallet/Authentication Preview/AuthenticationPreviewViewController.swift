import UIKit
import MixinServices

class AuthenticationPreviewViewController: UIViewController {
    
    let warnings: [String]
    let tableHeaderView = R.nib.authenticationPreviewHeaderView(withOwner: nil)!
    
    var tableView: UITableView!
    var canDismissInteractively = true
    var onDismiss: (() -> Void)?
    
    var tableViewStyle: UITableView.Style {
        .plain
    }
    
    private(set) var rows: [Row] = []
    private(set) var trayView: UIView?
    
    private var trayViewBottomConstraint: NSLayoutConstraint?
    private var trayViewCenterXConstraint: NSLayoutConstraint?
    
    private var unresolvedWarningIndex = 0
    
    init(warnings: [String]) {
        self.warnings = warnings
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        presentationController?.delegate = self
        
        loadTableView()
        tableView.backgroundColor = R.color.background()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.automaticallyAdjustsScrollIndicatorInsets = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 61
        tableView.separatorStyle = .none
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
        tableView.register(R.nib.tokenAmountCell)
        tableView.register(R.nib.paymentUserGroupCell)
        tableView.register(R.nib.web3MessageCell)
        tableView.register(R.nib.web3AmountChangeCell)
        tableView.register(R.nib.multipleAssetChangeCell)
        tableView.register(R.nib.addressReceiversCell)
        tableView.register(R.nib.authenticationPreviewWalletCell)
        tableView.register(R.nib.commonWalletReceiverCell)
        tableView.register(R.nib.waivedFeeCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        // Prevent frame from changing when set as `tableHeaderView`
        tableHeaderView.autoresizingMask = []
        
        loadInitialTrayView(animated: false)
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        layoutTableHeaderView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableViewBottomInset()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            layoutTableHeaderView()
        }
    }
    
    func loadTableView() {
        tableView = UITableView(frame: view.bounds, style: tableViewStyle)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
    }
    
    func layoutTableHeaderView() {
        let sizeToFit = CGSize(width: view.bounds.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let fittingSize = tableHeaderView.systemLayoutSizeFitting(sizeToFit,
                                                                  withHorizontalFittingPriority: .required,
                                                                  verticalFittingPriority: .fittingSizeLevel)
        tableHeaderView.frame = CGRect(origin: .zero, size: fittingSize)
        tableView.tableHeaderView = tableHeaderView
    }
    
    func layoutTableHeaderView(title: String, subtitle: String?, style: TableHeaderViewStyle = []) {
        tableHeaderView.titleLabel.text = title
        tableHeaderView.subtitleTextView.text = subtitle
        if style.contains(.destructive) {
            tableHeaderView.subtitleTextView.textColor = R.color.red()
        } else {
            tableHeaderView.subtitleTextView.textColor = R.color.text_secondary()
        }
        layoutTableHeaderView()
    }
    
    func reloadData(with rows: [Row]) {
        self.rows = rows
        tableView.reloadData()
    }
    
    func performAction(with pin: String) {
        
    }
    
    func replaceRow(at index: Int, with row: Row) {
        rows[index] = row
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    func insertRow(_ row: Row, at index: Int) {
        rows.insert(row, at: index)
        let indexPath = IndexPath(row: index, section: 0)
        tableView.insertRows(at: [indexPath], with: .none)
    }
    
    func tableView(_ tableView: UITableView, didSelectRow row: Row) {
        
    }
    
    private func updateTableViewBottomInset() {
        let safeAreaInset = max(view.safeAreaInsets.bottom, 20)
        let bottomInset = max(safeAreaInset, trayView?.frame.height ?? 0)
        tableView.contentInset.bottom = bottomInset
        tableView.verticalScrollIndicatorInsets.bottom = bottomInset
    }
    
}

// MARK: - UIAdaptivePresentationControllerDelegate
extension AuthenticationPreviewViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        canDismissInteractively
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }
    
}

// MARK: - UITableViewDataSource
extension AuthenticationPreviewViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case let .amount(caption, token, fiatMoney, display, boldPrimaryAmount):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            switch display {
            case .byToken:
                cell.primaryLabel.text = token
                cell.secondaryLabel.text = fiatMoney
            case .byFiatMoney:
                cell.primaryLabel.text = fiatMoney
                cell.secondaryLabel.text = token
            }
            cell.setPrimaryLabel(usesBoldFont: boldPrimaryAmount)
            cell.trailingContent = nil
            return cell
        case let .address(caption, address, label):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.setContent(address, labelContent: label)
            return cell
        case let .info(caption, content):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.setContent(content)
            return cell
        case let .boldInfo(caption, content):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.setBoldContent(content)
            return cell
        case let .doubleLineInfo(caption, primary, secondary):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.primaryLabel.text = primary
            cell.secondaryLabel.text = secondary
            cell.setPrimaryLabel(usesBoldFont: false)
            cell.trailingContent = nil
            return cell
        case let .senders(users, multisigSigners, threshold):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_user_group, for: indexPath)!
            cell.captionLabel.text = if let threshold {
                if users.count > 1 {
                    R.string.localizable.multisig_senders_threshold("\(threshold)/\(users.count)").uppercased()
                } else {
                    R.string.localizable.multisig_sender().uppercased()
                }
            } else {
                R.string.localizable.sender().uppercased()
            }
            if let signers = multisigSigners {
                cell.reloadUsers(with: users, checkmarkCondition: .byUserID(signers))
            } else {
                cell.reloadUsers(with: users, checkmarkCondition: .never)
            }
            cell.delegate = self
            return cell
        case let .receivers(users, threshold):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_user_group, for: indexPath)!
            cell.captionLabel.text = if let threshold {
                if users.count > 1 {
                    R.string.localizable.multisig_receivers_threshold("\(threshold)/\(users.count)").uppercased()
                } else {
                    R.string.localizable.multisig_receiver().uppercased()
                }
            } else {
                R.string.localizable.receiver().uppercased()
            }
            cell.reloadUsers(with: users, checkmarkCondition: .never)
            cell.delegate = self
            return cell
        case let .mainnetReceiver(address):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.setContent(address)
            return cell
        case let .web3Message(caption, message):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_message, for: indexPath)!
            cell.captionLabel.text = caption.uppercased()
            cell.messageTextView.text = message
            return cell
        case let .web3Amount(caption, content, token, chain):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_amount_change, for: indexPath)!
            cell.captionLabel.text = caption.uppercased()
            cell.reloadData(caption: caption, content: content, token: token, chain: chain)
            return cell
        case let .selectableFee(speed, tokenAmount, fiatMoneyAmount):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.fee_selection(speed).uppercased()
            cell.primaryLabel.text = tokenAmount
            cell.secondaryLabel.text = fiatMoneyAmount
            cell.setPrimaryLabel(usesBoldFont: false)
            cell.trailingContent = .disclosure
            return cell
        case let .tokenAmount(token, tokenAmount, fiatMoneyAmount):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_amount, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.token().uppercased()
            cell.amountLabel.text = tokenAmount
            cell.secondaryAmountLabel.text = fiatMoneyAmount
            cell.tokenIconView.setIcon(token: token)
            return cell
        case let .assetChanges(estimated, changes):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
            cell.titleLabel.text = if estimated {
                R.string.localizable.estimated_balance_change().uppercased()
            } else {
                R.string.localizable.balance_changes().uppercased()
            }
            cell.reloadData(changes: changes)
            return cell
        case let .safeMultisigAmount(token, tokenAmount, fiatMoneyAmount):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.total_amount().uppercased()
            cell.primaryLabel.text = tokenAmount
            cell.secondaryLabel.text = fiatMoneyAmount
            cell.setPrimaryLabel(usesBoldFont: true)
            cell.trailingContent = .plainTokenIcon(token)
            return cell
        case let .addressReceivers(token, receivers):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.address_receivers, for: indexPath)!
            cell.reloadData(token: token, recipients: receivers)
            return cell
        case let .wallet(caption, wallet, threshold):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_wallet, for: indexPath)!
            cell.captionLabel.text = switch caption {
            case .sender where threshold != nil:
                R.string.localizable.multisig_sender().uppercased()
            default:
                caption.rawValue.uppercased()
            }
            switch wallet {
            case .privacy:
                cell.nameLabel.text = R.string.localizable.privacy_wallet()
                cell.iconImageView.image = R.image.privacy_wallet()
                cell.iconImageView.isHidden = false
                cell.walletTag = nil
            case .common(let wallet):
                cell.nameLabel.text = wallet.name
                cell.iconImageView.isHidden = true
                cell.walletTag = nil
            case .safe(let wallet):
                cell.nameLabel.text = wallet.name
                cell.iconImageView.image = R.image.safe_vault()
                cell.iconImageView.isHidden = false
                cell.walletTag = wallet.role.localizedDescription
            }
            return cell
        case let .safe(name, role):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_wallet, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.safe().uppercased()
            cell.nameLabel.text = name
            cell.iconImageView.image = R.image.safe_vault()
            cell.iconImageView.isHidden = false
            cell.walletTag = role
            return cell
        case let .commonWalletReceiver(user, address):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.common_wallet_receiver, for: indexPath)!
            cell.userItemView.load(user: user)
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.addressLabel.text = address
            return cell
        case let .user(title, user):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_user_group, for: indexPath)!
            cell.captionLabel.text = title.uppercased()
            cell.reloadUsers(with: [user], checkmarkCondition: .never)
            cell.delegate = self
            return cell
        case let .waivedFee(token, fiatMoney, display):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.waived_fee, for: indexPath)!
            switch display {
            case .byToken:
                cell.updatePrimaryLabel(text: token)
                cell.secondaryLabel.text = fiatMoney
            case .byFiatMoney:
                cell.updatePrimaryLabel(text: fiatMoney)
                cell.secondaryLabel.text = token
            }
            return cell
        }
    }
    
}

// MARK: - UITableViewDelegate
extension AuthenticationPreviewViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        self.tableView(tableView, didSelectRow: row)
    }
    
}

// MARK: - PaymentUserGroupCellDelegate
extension AuthenticationPreviewViewController: PaymentUserGroupCellDelegate {
    
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem) {
        let controller = UserProfileViewController(user: item)
        controller.dismissPresentingViewControllerOnNavigation = true
        present(controller, animated: true, completion: nil)
    }
    
}

// MARK: - Data Structure
extension AuthenticationPreviewViewController {
    
    enum Caption {
        
        case amount
        case label
        case address
        case network
        case fee
        case networkFee
        case memo
        case tag
        case total
        case totalAmount
        case wallet
        case sender
        case receiver
        case collectible
        case price
        case from
        case safe
        case note
        case balance
        case availableBalance
        case string(String)
        
        var rawValue: String {
            switch self {
            case .amount:
                R.string.localizable.amount()
            case .label:
                R.string.localizable.label()
            case .address:
                R.string.localizable.address()
            case .network:
                R.string.localizable.network()
            case .fee:
                R.string.localizable.fee()
            case .networkFee:
                R.string.localizable.network_fee()
            case .memo:
                R.string.localizable.memo()
            case .tag:
                R.string.localizable.tag()
            case .total:
                R.string.localizable.total()
            case .totalAmount:
                R.string.localizable.total_amount()
            case .wallet:
                R.string.localizable.wallet()
            case .sender:
                R.string.localizable.sender()
            case .receiver:
                R.string.localizable.receiver()
            case .collectible:
                R.string.localizable.collectible()
            case .price:
                R.string.localizable.price()
            case .from:
                R.string.localizable.from()
            case .safe:
                R.string.localizable.safe()
            case .note:
                R.string.localizable.note()
            case .balance:
                R.string.localizable.balance()
            case .availableBalance:
                R.string.localizable.available_balance()
            case .string(let value):
                value
            }
        }
        
    }
    
    enum Row {
        case amount(caption: Caption, token: String, fiatMoney: String, display: AmountIntent, boldPrimaryAmount: Bool)
        case info(caption: Caption, content: String)
        case boldInfo(caption: Caption, content: String)
        case doubleLineInfo(caption: Caption, primary: String, secondary: String)
        case address(caption: Caption, address: String, label: AddressLabel?)
        case senders([UserItem], multisigSigners: Set<String>?, threshold: Int32?)
        case receivers([UserItem], threshold: Int32?)
        case mainnetReceiver(String)
        case web3Message(caption: String, message: String)
        case web3Amount(caption: String, content: Web3AmountChangeCell.Content, token: (any Token)?, chain: Chain?)
        case selectableFee(speed: String, tokenAmount: String, fiatMoneyAmount: String)
        case tokenAmount(token: MixinTokenItem, tokenAmount: String, fiatMoneyAmount: String)
        case assetChanges(estimated: Bool, changes: [StyledAssetChange])
        case safeMultisigAmount(token: MixinTokenItem, tokenAmount: String, fiatMoneyAmount: String)
        case addressReceivers(MixinTokenItem, [SafeMultisigResponse.Safe.Recipient])
        case wallet(caption: Caption, wallet: Wallet, threshold: Int32?)
        case safe(name: String, role: String)
        case commonWalletReceiver(user: UserItem, address: String)
        case user(title: String, user: UserItem)
        case waivedFee(token: String, fiatMoney: String, display: AmountIntent)
    }
    
    struct TableHeaderViewStyle: OptionSet {
        
        let rawValue: UInt
        
        static let destructive = TableHeaderViewStyle(rawValue: 1 << 0)
        
    }
    
}

// MARK: - Initial Tray View
extension AuthenticationPreviewViewController {
    
    @objc func loadInitialTrayView(animated: Bool) {
        if unresolvedWarningIndex < warnings.count {
            let warning = warnings[unresolvedWarningIndex]
            let animation: TrayViewAnimation? = if animated {
                unresolvedWarningIndex == 0 ? .vertical : .horizontal
            } else {
                nil
            }
            loadDialogTrayView(animation: animation) { view in
                view.iconImageView.image = R.image.ic_warning()?.withRenderingMode(.alwaysTemplate)
                if warnings.count > 1 {
                    view.stepLabel.text = "\(unresolvedWarningIndex + 1)/\(warnings.count)"
                }
                view.titleLabel.text = warning
                view.leftButton.isHidden = true
                view.rightButton.setTitle(R.string.localizable.got_it(), for: .normal)
                view.rightButton.addTarget(self, action: #selector(ignoreCurrentWarning(_:)), for: .touchUpInside)
                view.style = .red
            }
            unresolvedWarningIndex += 1
        } else {
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.confirm(),
                                     rightAction: #selector(confirm(_:)),
                                     animation: animated ? .vertical : nil)
        }
    }
    
    @objc private func ignoreCurrentWarning(_ sender: Any) {
        loadInitialTrayView(animated: true)
    }
    
    @objc func confirm(_ sender: Any) {
        let intent = PreviewedAuthenticationIntent(onInput: performAction(with:))
        let authentication = AuthenticationViewController(intent: intent)
        present(authentication, animated: true)
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: onDismiss)
    }
    
}

// MARK: - Finished Tray View
extension AuthenticationPreviewViewController {
    
    func loadFinishedTrayView() {
        
        func loadBiometricAuthenticationDialogView(icon: UIImage, type: String) {
            loadDialogTrayView(animation: .vertical) { view in
                view.iconImageView.image = icon.withRenderingMode(.alwaysTemplate)
                view.titleLabel.text = R.string.localizable.enable_bioauth_description(type, type)
                view.leftButton.setTitle(R.string.localizable.enable(), for: .normal)
                view.leftButton.addTarget(self, action: #selector(enableBiometricAuthentication(_:)), for: .touchUpInside)
                view.rightButton.setTitle(R.string.localizable.not_now(), for: .normal)
                view.rightButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                view.style = .gray
            }
        }
        
        switch BiometryType.payment {
        case .faceID where !AppGroupUserDefaults.Wallet.payWithBiometricAuthentication:
            loadBiometricAuthenticationDialogView(icon: R.image.ic_pay_face()!, type: R.string.localizable.face_id())
        case .touchID where !AppGroupUserDefaults.Wallet.payWithBiometricAuthentication:
            loadBiometricAuthenticationDialogView(icon: R.image.ic_pay_touch()!, type: R.string.localizable.touch_id())
        case .faceID, .touchID, .none:
            loadSingleButtonTrayView(title: R.string.localizable.done(), action: #selector(close(_:)))
        }
    }
    
    @objc func enableBiometricAuthentication(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) {
            guard let navigationController = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigationController.viewControllers
            if let viewController = viewControllers.first {
                viewControllers = [viewController]
            }
            viewControllers.append(PinSettingsViewController())
            navigationController.setViewControllers(viewControllers, animated: true)
        }
    }
    
}

// MARK: - Tray View Loader
extension AuthenticationPreviewViewController {
    
    enum TrayViewAnimation {
        case vertical
        case horizontal
    }
    
    func loadSingleButtonTrayView(title: String, action: Selector) {
        let trayView = AuthenticationPreviewSingleButtonTrayView()
        trayView.button.setTitle(title, for: .normal)
        replaceTrayView(with: trayView, animation: .vertical)
        trayView.button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    func loadDoubleButtonTrayView(
        leftTitle: String,
        leftAction: Selector,
        rightTitle: String,
        rightAction: Selector,
        animation: TrayViewAnimation?
    ) {
        let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
        UIView.performWithoutAnimation {
            trayView.leftButton.setTitle(leftTitle, for: .normal)
            trayView.leftButton.layoutIfNeeded()
            trayView.rightButton.setTitle(rightTitle, for: .normal)
            trayView.rightButton.layoutIfNeeded()
        }
        replaceTrayView(with: trayView, animation: animation)
        trayView.leftButton.addTarget(self, action: leftAction, for: .touchUpInside)
        trayView.rightButton.addTarget(self, action: rightAction, for: .touchUpInside)
    }
    
    func loadDialogTrayView(animation: TrayViewAnimation?, configuration: (AuthenticationPreviewDialogView) -> Void) {
        let trayView = R.nib.authenticationPreviewDialogView(withOwner: nil)!
        configuration(trayView)
        replaceTrayView(with: trayView, animation: animation)
    }
    
    func replaceTrayView(with newTrayView: UIView?, animation: TrayViewAnimation?) {
        if let oldTrayView = trayView, let bottomConstraint = trayViewBottomConstraint, let centerXConstraint = trayViewCenterXConstraint {
            switch animation {
            case .vertical:
                bottomConstraint.constant = oldTrayView.frame.height / 2
                UIView.animate(withDuration: 0.3) {
                    oldTrayView.alpha = 0
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    oldTrayView.removeFromSuperview()
                    if newTrayView == nil {
                        self.updateTableViewBottomInset()
                    }
                }
            case .horizontal:
                centerXConstraint.constant = -oldTrayView.frame.width / 2
                UIView.animate(withDuration: 0.3) {
                    oldTrayView.alpha = 0
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    oldTrayView.removeFromSuperview()
                    if newTrayView == nil {
                        self.updateTableViewBottomInset()
                    }
                }
            case nil:
                oldTrayView.removeFromSuperview()
                if newTrayView == nil {
                    updateTableViewBottomInset()
                }
            }
        }
        
        if let newTrayView {
            if animation != nil {
                newTrayView.alpha = 0
            }
            
            view.addSubview(newTrayView)
            newTrayView.translatesAutoresizingMaskIntoConstraints = false
            let widthConstraint = newTrayView.widthAnchor.constraint(equalTo: view.widthAnchor)
            let centerXConstraint = newTrayView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            let bottomConstraint = newTrayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            NSLayoutConstraint.activate([widthConstraint, centerXConstraint, bottomConstraint])
            
            self.trayView = newTrayView
            self.trayViewCenterXConstraint = centerXConstraint
            self.trayViewBottomConstraint = bottomConstraint
            
            switch animation {
            case .vertical:
                newTrayView.layoutIfNeeded()
                bottomConstraint.constant = newTrayView.frame.height / 2
                view.layoutIfNeeded()
                bottomConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    newTrayView.alpha = 1
                } completion: { _ in
                    self.updateTableViewBottomInset()
                }
            case .horizontal:
                newTrayView.layoutIfNeeded()
                centerXConstraint.constant = newTrayView.frame.width / 2
                view.layoutIfNeeded()
                centerXConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    newTrayView.alpha = 1
                } completion: { _ in
                    self.updateTableViewBottomInset()
                }
            case nil:
                // Reduce `UITableViewAlertForLayoutOutsideViewHierarchy`
                if view.window != nil {
                    view.layoutIfNeeded()
                }
                updateTableViewBottomInset()
            }
        } else {
            self.trayView = nil
            self.trayViewCenterXConstraint = nil
            self.trayViewBottomConstraint = nil
        }
    }
    
}

// MARK: - PreviewedAuthenticationIntent
extension AuthenticationPreviewViewController {
    
    private final class PreviewedAuthenticationIntent: AuthenticationIntent {
        
        let intentTitle: String = R.string.localizable.continue_with_pin()
        let intentTitleIcon: UIImage? = R.image.ic_pin_setting()
        let intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? = nil
        let intentSubtitle = ""
        let options: AuthenticationIntentOptions = [
            .allowsBiometricAuthentication,
            .becomesFirstResponderOnAppear,
            .neverRequestAddBiometricAuthentication,
        ]
        let authenticationViewController: AuthenticationViewController? = nil
        
        private let onInput: (String) -> Void
        
        init(onInput: @escaping (String) -> Void) {
            self.onInput = onInput
        }
        
        @MainActor
        func authenticationViewController(
            _ controller: AuthenticationViewController,
            didInput pin: String,
            completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
        ) {
            completion(.success)
            onInput(pin)
            controller.presentingViewController?.dismiss(animated: true)
        }
        
        func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
            
        }
        
    }
    
}
