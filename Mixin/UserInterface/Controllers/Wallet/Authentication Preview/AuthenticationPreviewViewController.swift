import UIKit
import MixinServices

class AuthenticationPreviewViewController: UIViewController {
    
    let warnings: [String]
    let tableView = UITableView()
    let tableHeaderView = R.nib.authenticationPreviewHeaderView(withOwner: nil)!
    
    var canDismissInteractively = true
    
    var authenticationTitle: String {
        R.string.localizable.send_by_pin()
    }
    
    private var rows: [Row] = []
    
    private var trayView: UIView?
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
        
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = R.color.background()
        tableView.allowsSelection = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.automaticallyAdjustsScrollIndicatorInsets = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 61
        tableView.separatorStyle = .none
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
        tableView.register(R.nib.paymentFeeCell)
        tableView.register(R.nib.paymentUserGroupCell)
        tableView.dataSource = self
        
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
        let bottomInset = max(view.safeAreaInsets.bottom, trayView?.frame.height ?? 0)
        UIView.animate(withDuration: 0.3) {
            self.tableView.contentInset.bottom = bottomInset
            self.tableView.verticalScrollIndicatorInsets.bottom = bottomInset
            if self.tableView.contentSize.height + bottomInset < self.tableView.frame.height {
                self.tableView.setContentOffset(.zero, animated: false)
            }
        }
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
        tableHeaderView.subtitleLabel.text = subtitle
        if style.contains(.destructive) {
            tableHeaderView.subtitleLabel.textColor = R.color.red()
        } else {
            tableHeaderView.subtitleLabel.textColor = R.color.text_secondary()
        }
        layoutTableHeaderView()
    }
    
    func reloadData(with rows: [Row]) {
        self.rows = rows
        tableView.reloadData()
    }
    
    func performAction(with pin: String) {
        
    }
    
}

// MARK: - UIAdaptivePresentationControllerDelegate
extension AuthenticationPreviewViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        canDismissInteractively
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
            cell.setPrimaryAmountLabel(usesBoldFont: boldPrimaryAmount)
            return cell
        case let .receivingAddress(value, label):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.setContent(value, labelContent: label)
            return cell
        case let .info(caption, content):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.setContent(content, labelContent: nil)
            return cell
        case let .senders(users, threshold):
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
            cell.users = users
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
            cell.users = users
            cell.delegate = self
            return cell
        case let .mainnetReceiver(address):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.setContent(address, labelContent: nil)
            return cell
        }
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
        case memo
        case tag
        case total
        
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
            case .memo:
                R.string.localizable.memo()
            case .tag:
                R.string.localizable.tag()
            case .total:
                R.string.localizable.total()
            }
        }
        
    }
    
    enum Row {
        case amount(caption: Caption, token: String, fiatMoney: String, display: AmountIntent, boldPrimaryAmount: Bool)
        case info(caption: Caption, content: String)
        case receivingAddress(value: String, label: String?)
        case senders([UserItem], threshold: Int32?)
        case receivers([UserItem], threshold: Int32?)
        case mainnetReceiver(String)
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
                view.style = .warning
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
        let intent = PreviewedAuthenticationIntent(title: authenticationTitle, onInput: performAction(with:))
        let authentication = AuthenticationViewController(intent: intent)
        present(authentication, animated: true)
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
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
                view.style = .info
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
            viewControllers.append(PinSettingsViewController.instance())
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
                }
            case .horizontal:
                centerXConstraint.constant = -oldTrayView.frame.width / 2
                UIView.animate(withDuration: 0.3) {
                    oldTrayView.alpha = 0
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    oldTrayView.removeFromSuperview()
                }
            case nil:
                oldTrayView.removeFromSuperview()
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
            
            switch animation {
            case .vertical:
                newTrayView.layoutIfNeeded()
                bottomConstraint.constant = newTrayView.frame.height / 2
                view.layoutIfNeeded()
                bottomConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    newTrayView.alpha = 1
                }
            case .horizontal:
                newTrayView.layoutIfNeeded()
                centerXConstraint.constant = newTrayView.frame.width / 2
                view.layoutIfNeeded()
                centerXConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    newTrayView.alpha = 1
                }
            case nil:
                // Reduce `UITableViewAlertForLayoutOutsideViewHierarchy`
                if view.window != nil {
                    view.layoutIfNeeded()
                }
            }
            
            self.trayView = newTrayView
            self.trayViewCenterXConstraint = centerXConstraint
            self.trayViewBottomConstraint = bottomConstraint
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
        
        let intentTitle: String
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
        
        init(title: String, onInput: @escaping (String) -> Void) {
            self.intentTitle = title
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