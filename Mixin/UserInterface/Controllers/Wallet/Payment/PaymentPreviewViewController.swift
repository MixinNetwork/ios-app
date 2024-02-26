import UIKit
import MixinServices

class PaymentPreviewViewController: UIViewController {
    
    let issues: [PaymentPreconditionIssue]
    let tableView = UITableView()
    let tableHeaderView = R.nib.paymentPreviewHeaderView(withOwner: nil)!
    
    var canDismissInteractively = true
    
    var authenticationTitle: String {
        R.string.localizable.send_by_pin()
    }
    
    private var rows: [Row] = []
    
    private var trayView: UIView?
    private var trayViewBottomConstraint: NSLayoutConstraint?
    private var trayViewCenterXConstraint: NSLayoutConstraint?
    
    private var unresolvedIssueIndex = 0
    
    init(issues: [PaymentPreconditionIssue]) {
        self.issues = issues
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
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 61
        tableView.separatorStyle = .none
        tableView.register(R.nib.paymentAmountCell)
        tableView.register(R.nib.paymentInfoCell)
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
extension PaymentPreviewViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        canDismissInteractively
    }
    
}

// MARK: - UITableViewDataSource
extension PaymentPreviewViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case let .amount(caption, token, fiatMoney, display):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_amount, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            switch display {
            case .byToken:
                cell.amountLabel.text = token
                cell.secondaryAmountLabel.text = fiatMoney
            case .byFiatMoney:
                cell.amountLabel.text = fiatMoney
                cell.secondaryAmountLabel.text = token
            }
            return cell
        case let .address(value, label):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_info, for: indexPath)!
            cell.captionLabel.text = Caption.address.rawValue.uppercased()
            cell.contentLabel.attributedText = {
                var attributes: [NSAttributedString.Key: Any] = [:]
                if let font = cell.contentLabel.font {
                    attributes[.font] = font
                }
                if let textColor = cell.contentLabel.textColor {
                    attributes[.foregroundColor] = textColor
                }
                return NSMutableAttributedString(string: value, attributes: attributes)
            }()
            return cell
        case let .info(caption, content):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_info, for: indexPath)!
            cell.captionLabel.text = caption.rawValue.uppercased()
            cell.contentLabel.text = content
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
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.contentLabel.text = address
            return cell
        case let .fee(token, fiatMoney, display):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_fee, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.network_fee().uppercased()
            switch display {
            case .byToken:
                cell.amountLabel.text = token
                cell.secondaryAmountLabel.text = fiatMoney
            case .byFiatMoney:
                cell.amountLabel.text = fiatMoney
                cell.secondaryAmountLabel.text = token
            }
            return cell
        }
    }
    
}

// MARK: - PaymentUserGroupCellDelegate
extension PaymentPreviewViewController: PaymentUserGroupCellDelegate {
    
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem) {
        let controller = UserProfileViewController(user: item)
        controller.dismissPresentingViewControllerOnNavigation = true
        present(controller, animated: true, completion: nil)
    }
    
}

// MARK: - Data Structure
extension PaymentPreviewViewController {
    
    enum Caption {
        
        case amount
        case label
        case address
        case network
        case fee
        case memo
        case receiverWillReceive
        case addressWillReceive
        
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
                R.string.localizable.network_fee()
            case .memo:
                R.string.localizable.memo()
            case .receiverWillReceive:
                R.string.localizable.receiver_will_receive()
            case .addressWillReceive:
                R.string.localizable.address_will_receive()
            }
        }
        
    }
    
    enum Row {
        case amount(caption: Caption, token: String, fiatMoney: String, display: AmountIntent)
        case info(caption: Caption, content: String)
        case address(value: String, label: String?)
        case senders([UserItem], threshold: Int32?)
        case receivers([UserItem], threshold: Int32?)
        case mainnetReceiver(String)
        case fee(token: String, fiatMoney: String, display: AmountIntent)
    }
    
    struct TableHeaderViewStyle: OptionSet {
        
        let rawValue: UInt
        
        static let destructive = TableHeaderViewStyle(rawValue: 1 << 0)
        
    }
    
}

// MARK: - Initial Tray View
extension PaymentPreviewViewController {
    
    @objc func loadInitialTrayView(animated: Bool) {
        if unresolvedIssueIndex < issues.count {
            let issue = issues[unresolvedIssueIndex]
            let animation: TrayViewAnimation? = if animated {
                unresolvedIssueIndex == 0 ? .vertical : .horizontal
            } else {
                nil
            }
            loadDialogTrayView(animation: animation) { view in
                view.iconImageView.image = R.image.ic_warning()?.withRenderingMode(.alwaysTemplate)
                if issues.count > 1 {
                    view.stepLabel.text = "\(unresolvedIssueIndex + 1)/\(issues.count)"
                }
                view.titleLabel.text = issue.description
                view.leftButton.setTitle(R.string.localizable.cancel(), for: .normal)
                view.leftButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                view.rightButton.setTitle(R.string.localizable.confirm(), for: .normal)
                view.rightButton.addTarget(self, action: #selector(ignoreCurrentIssue(_:)), for: .touchUpInside)
                view.style = .warning
            }
            unresolvedIssueIndex += 1
        } else {
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.confirm(),
                                     rightAction: #selector(confirm(_:)),
                                     animation: animated ? .vertical : nil)
        }
    }
    
    @objc private func ignoreCurrentIssue(_ sender: Any) {
        loadInitialTrayView(animated: true)
    }
    
    @objc func confirm(_ sender: Any) {
        let intent = PaymentPreviewAuthenticationIntent(title: authenticationTitle, onInput: performAction(with:))
        let authentication = AuthenticationViewController(intent: intent)
        present(authentication, animated: true)
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

// MARK: - Finished Tray View
extension PaymentPreviewViewController {
    
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
extension PaymentPreviewViewController {
    
    enum TrayViewAnimation {
        case vertical
        case horizontal
    }
    
    func loadSingleButtonTrayView(title: String, action: Selector) {
        let trayView = PaymentPreviewSingleButtonTrayView()
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
        let trayView = R.nib.paymentPreviewDoubleButtonTrayView(withOwner: nil)!
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
    
    func loadDialogTrayView(animation: TrayViewAnimation?, configuration: (PaymentPreviewDialogView) -> Void) {
        let trayView = R.nib.paymentPreviewDialogView(withOwner: nil)!
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
            self.tableView.contentInset.bottom = newTrayView.frame.height
            self.tableView.verticalScrollIndicatorInsets.bottom = newTrayView.frame.height
        } else {
            self.trayView = nil
            self.trayViewCenterXConstraint = nil
            self.trayViewBottomConstraint = nil
            self.tableView.contentInset.bottom = 0
            self.tableView.verticalScrollIndicatorInsets.bottom = 0
        }
    }
    
}
