import UIKit
import MixinServices

class TokenReceiverViewController: KeyboardBasedLayoutViewController {
    
    let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    
    weak var tableView: UITableView!
    
    private let trayViewHeight: CGFloat = 82
    
    private weak var trayView: TokenReceiverTrayView?
    private weak var trayViewBottomConstraint: NSLayoutConstraint?
    
    var nextButton: StyledButton? {
        return trayView?.nextButton
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        headerView.inputPlaceholder = R.string.localizable.hint_address()
        headerView.delegate = self
        
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background_secondary()
        tableView.separatorStyle = .none
        tableView.tableHeaderView = headerView
        tableView.register(R.nib.sendingDestinationCell)
        tableView.estimatedRowHeight = 74
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 35, right: 0)
        tableView.keyboardDismissMode = .onDrag
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func layout(for keyboardFrame: CGRect) {
        if let constraint = trayViewBottomConstraint {
            constraint.constant = -keyboardFrame.height
            view.layoutIfNeeded()
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "send_recipient", "wallet": "main"])
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if let constraint = trayViewBottomConstraint {
            constraint.constant = 0
            view.layoutIfNeeded()
        }
    }
    
    @objc private func continueWithOneTimeAddress(_ sender: Any) {
        let userInput = headerView.trimmedContent
        guard !userInput.isEmpty else {
            return
        }
        
        trayView?.nextButton.isBusy = true
        continueAction(inputAddress: userInput)
    }
    
    func continueAction(inputAddress: String) {
        
    }
    
    func showError(description: String) {
        guard let trayView else {
            return
        }
        trayView.nextButton.isBusy = false
        trayView.errorDescriptionLabel.text = description
        trayView.errorDescriptionLabel.isHidden = false
    }
    
}

extension TokenReceiverViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension TokenReceiverViewController: AddressInfoInputHeaderView.Delegate {
    
    func addressInfoInputHeaderView(_ headerView: AddressInfoInputHeaderView, didUpdateContent content: String) {
        let newHeaderSize = headerView.systemLayoutSizeFitting(
            CGSize(width: headerView.bounds.width, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        headerView.frame.size.height = newHeaderSize.height
        tableView.tableHeaderView = headerView
        if content.isEmpty {
            tableView.dataSource = self as? UITableViewDataSource
            tableView.contentInset.bottom = 0
            trayView?.isHidden = true
        } else {
            tableView.dataSource = nil
            tableView.contentInset.bottom = trayViewHeight
            if let trayView {
                trayView.isHidden = false
                trayView.errorDescriptionLabel.isHidden = true
            } else {
                let trayView = R.nib.tokenReceiverTrayView(withOwner: nil)!
                view.addSubview(trayView)
                trayView.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                }
                trayView.nextButton.addTarget(
                    self,
                    action: #selector(continueWithOneTimeAddress(_:)),
                    for: .touchUpInside
                )
                let bottomConstraint = trayView.bottomAnchor.constraint(
                    equalTo: view.bottomAnchor,
                    constant: -(lastKeyboardFrame?.height ?? 0)
                )
                bottomConstraint.priority = .defaultHigh
                bottomConstraint.isActive = true
                self.trayView = trayView
                self.trayViewBottomConstraint = bottomConstraint
            }
        }
        tableView.reloadData()
    }
    
    func addressInfoInputHeaderViewWantsToScanContent(_ headerView: AddressInfoInputHeaderView) {
        let scanner = QRCodeScannerViewController()
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
}

extension TokenReceiverViewController: QRCodeScannerViewControllerDelegate {
    
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, shouldRecognizeString string: String) -> Bool {
        let destination = IBANAddress(string: string)?.standarizedAddress ?? string
        headerView.setContent(destination)
        continueWithOneTimeAddress(controller)
        return false
    }
    
}
