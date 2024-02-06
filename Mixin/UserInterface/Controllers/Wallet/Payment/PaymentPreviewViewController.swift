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
    
    func layoutTableHeaderView(title: String, subtitle: String?) {
        tableHeaderView.titleLabel.text = title
        tableHeaderView.subtitleLabel.text = subtitle
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
        case let .amount(token, fiatMoney):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_amount, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.amount().uppercased()
            cell.tokenAmountLabel.text = token
            cell.fiatMoneyAmountLabel.text = fiatMoney
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
            if let threshold, users.count > 1 {
                let threshold = "\(threshold)/\(users.count)"
                cell.captionLabel.text = R.string.localizable.multisig_senders_threshold(threshold).uppercased()
            } else {
                cell.captionLabel.text = R.string.localizable.sender().uppercased()
            }
            cell.users = users
            cell.delegate = self
            return cell
        case let .receivers(users, threshold):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_user_group, for: indexPath)!
            if let threshold, users.count > 1 {
                let threshold = "\(threshold)/\(users.count)"
                cell.captionLabel.text = R.string.localizable.multisig_receivers_threshold(threshold).uppercased()
            } else {
                cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            }
            cell.users = users
            cell.delegate = self
            return cell
        case let .mainnetReceiver(address):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_info, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.receiver().uppercased()
            cell.contentLabel.text = address
            return cell
        case let .fee(token, fiatMoney):
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_fee, for: indexPath)!
            cell.captionLabel.text = R.string.localizable.network_fee().uppercased()
            cell.tokenAmountLabel.text = token
            cell.fiatMoneyAmountLabel.text = fiatMoney
            return cell
        }
    }
    
}

// MARK: - PaymentUserGroupCellDelegate
extension PaymentPreviewViewController: PaymentUserGroupCellDelegate {
    
    func paymentUserGroupCellHeightDidUpdate(_ cell: PaymentUserGroupCell) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
}

// MARK: - Data Structure
extension PaymentPreviewViewController {
    
    enum Caption {
        
        case label
        case address
        case network
        case fee
        case memo
        case receiverWillReceive
        case addressWillReceive
        
        var rawValue: String {
            switch self {
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
        case amount(token: String, fiatMoney: String)
        case info(caption: Caption, content: String)
        case address(value: String, label: String?)
        case senders([UserItem], threshold: Int32?)
        case receivers([UserItem], threshold: Int32?)
        case mainnetReceiver(String)
        case fee(token: String, fiatMoney: String)
    }
    
}

// MARK: - Initial Tray View
extension PaymentPreviewViewController {
    
    func loadInitialTrayView(animated: Bool) {
        if unresolvedIssueIndex < issues.count {
            let issue = issues[unresolvedIssueIndex]
            loadDialogTrayView(animated: animated) { view in
                view.iconImageView.image = R.image.ic_warning()?.withRenderingMode(.alwaysTemplate)
                if issues.count > 1 {
                    view.stepLabel.text = "\(unresolvedIssueIndex + 1)/\(issues.count)"
                }
                view.titleLabel.text = issue.description
                view.leftButton.setTitle(R.string.localizable.confirm(), for: .normal)
                view.leftButton.addTarget(self, action: #selector(ignoreCurrentIssue(_:)), for: .touchUpInside)
                view.rightButton.setTitle(R.string.localizable.cancel(), for: .normal)
                view.rightButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                view.style = .warning
            }
            unresolvedIssueIndex += 1
        } else {
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.confirm(),
                                     rightAction: #selector(confirm(_:)),
                                     animated: animated)
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
            loadDialogTrayView(animated: true) { view in
                view.iconImageView.image = icon.withRenderingMode(.alwaysTemplate)
                view.titleLabel.text = R.string.localizable.enable_bioauth_description(type, type)
                view.leftButton.setTitle(R.string.localizable.enable(), for: .normal)
                view.leftButton.addTarget(self, action: #selector(enableBiometricAuthentication(_:)), for: .touchUpInside)
                view.rightButton.setTitle(R.string.localizable.not_now(), for: .normal)
                view.rightButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
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
    
    @objc func finish(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

// MARK: - Tray View Loader
extension PaymentPreviewViewController {
    
    func loadSingleButtonTrayView(title: String, action: Selector) {
        let trayView = PaymentPreviewSingleButtonTrayView()
        trayView.button.setTitle(title, for: .normal)
        replaceTrayView(with: trayView, animated: false)
        trayView.button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    func loadDoubleButtonTrayView(leftTitle: String, leftAction: Selector, rightTitle: String, rightAction: Selector, animated: Bool) {
        let trayView = R.nib.paymentPreviewDoubleButtonTrayView(withOwner: nil)!
        UIView.performWithoutAnimation {
            trayView.leftButton.setTitle(leftTitle, for: .normal)
            trayView.leftButton.layoutIfNeeded()
            trayView.rightButton.setTitle(rightTitle, for: .normal)
            trayView.rightButton.layoutIfNeeded()
        }
        replaceTrayView(with: trayView, animated: animated)
        trayView.leftButton.addTarget(self, action: leftAction, for: .touchUpInside)
        trayView.rightButton.addTarget(self, action: rightAction, for: .touchUpInside)
    }
    
    func loadDialogTrayView(animated: Bool, configuration: (PaymentPreviewDialogView) -> Void) {
        let trayView = R.nib.paymentPreviewDialogView(withOwner: nil)!
        configuration(trayView)
        replaceTrayView(with: trayView, animated: animated)
    }
    
    func replaceTrayView(with newTrayView: UIView?, animated: Bool) {
        if let oldTrayView = trayView, let constraint = trayViewBottomConstraint {
            if animated {
                constraint.constant = oldTrayView.frame.height / 2
                UIView.animate(withDuration: 0.3) {
                    oldTrayView.alpha = 0
                    self.view.layoutIfNeeded()
                } completion: { _ in
                    oldTrayView.removeFromSuperview()
                }
            } else {
                oldTrayView.removeFromSuperview()
            }
        }
        
        if let newTrayView {
            if animated {
                newTrayView.alpha = 0
            }
            
            view.addSubview(newTrayView)
            newTrayView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
            let bottomConstraint = newTrayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            bottomConstraint.isActive = true
            
            if animated {
                newTrayView.layoutIfNeeded()
                bottomConstraint.constant = newTrayView.frame.height / 2
                view.layoutIfNeeded()
                bottomConstraint.constant = 0
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                    newTrayView.alpha = 1
                }
            }
            
            self.trayView = newTrayView
            self.trayViewBottomConstraint = bottomConstraint
        } else {
            self.trayView = nil
            self.trayViewBottomConstraint = nil
        }
    }
    
}
