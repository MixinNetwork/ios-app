import UIKit
import MixinServices

final class TokenReceiverViewController: KeyboardBasedLayoutViewController {
    
    private enum Destination: Int, CaseIterable {
        case contact = 0
        case addressBook
    }
    
    private let token: TokenItem
    private let destinations: [Destination] = Destination.allCases
    private let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    private let trayViewHeight: CGFloat = 82
    
    private weak var tableView: UITableView!
    private weak var trayView: AuthenticationPreviewSingleButtonTrayView?
    
    private weak var trayViewBottomConstraint: NSLayoutConstraint?
    
    init(token: TokenItem) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = R.string.localizable.send()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        
        headerView.load(token: token)
        headerView.inputPlaceholder = "Enter a wallet address, exchange address, or ENS."
        headerView.delegate = self
        
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background_secondary()
        tableView.separatorStyle = .none
        tableView.tableHeaderView = headerView
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
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
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if let constraint = trayViewBottomConstraint {
            constraint.constant = 0
            view.layoutIfNeeded()
        }
    }
    
    @objc private func continueWithOneTimeAddress(_ sender: Any) {
        let destination = headerView.trimmedContent
        guard !destination.isEmpty else {
            return
        }
        if let nextInput = AddressInfoInputViewController.oneTimeWithdraw(token: token, destination: destination) {
            navigationController?.pushViewController(nextInput, animated: true)
        } else {
            let address = TemporaryAddress(destination: destination, tag: "")
            let inputAmount = WithdrawInputAmountViewController(
                tokenItem: token,
                destination: .temporary(address)
            )
            navigationController?.pushViewController(inputAmount, animated: true)
        }
    }
    
}

extension TokenReceiverViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension TokenReceiverViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let destination = Destination(rawValue: indexPath.row)!
        switch destination {
        case .contact:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            cell.iconImageView.image = R.image.wallet.send_destination_contact()
            cell.titleLabel.text = R.string.localizable.send_to_contact()
            cell.freeLabel.isHidden = false
            cell.subtitleLabel.text = R.string.localizable.send_to_contact_description()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        case .addressBook:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            cell.iconImageView.image = R.image.wallet.send_destination_address()
            cell.titleLabel.text = R.string.localizable.send_to_address()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_address_description()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        }
    }
    
}

extension TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        74
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Destination(rawValue: indexPath.row)! {
        case .contact:
            let selector = TransferReceiverViewController()
            selector.onSelect = { [token] (user) in
                self.dismiss(animated: true) {
                    let inputAmount = TransferInputAmountViewController(tokenItem: token, receiver: user)
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            self.present(selector, animated: true)
        case .addressBook:
            let book = AddressBookViewController(token: token)
            book.onSelect = { [token] (address) in
                self.dismiss(animated: true) {
                    let inputAmount = WithdrawInputAmountViewController(tokenItem: token, destination: .address(address))
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            present(book, animated: true)
        }
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
            tableView.dataSource = self
            tableView.contentInset.bottom = 0
            trayView?.isHidden = true
        } else {
            tableView.dataSource = nil
            tableView.contentInset.bottom = trayViewHeight
            if let trayView {
                trayView.isHidden = false
            } else {
                let trayView = AuthenticationPreviewSingleButtonTrayView()
                trayView.backgroundColor = R.color.background_secondary()
                view.addSubview(trayView)
                trayView.snp.makeConstraints { make in
                    make.height.equalTo(trayViewHeight)
                    make.leading.trailing.equalToSuperview()
                    make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom)
                }
                trayView.button.setTitle(R.string.localizable.next(), for: .normal)
                trayView.button.addTarget(self, action: #selector(continueWithOneTimeAddress(_:)), for: .touchUpInside)
                let bottomConstraint = trayView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(lastKeyboardFrame?.height ?? 0))
                bottomConstraint.priority = .defaultHigh
                bottomConstraint.isActive = true
                self.trayView = trayView
                self.trayViewBottomConstraint = bottomConstraint
            }
        }
        tableView.reloadData()
    }
    
    func addressInfoInputHeaderViewWantsToScanContent(_ headerView: AddressInfoInputHeaderView) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
}

extension TokenReceiverViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        let destination = IBANAddress(string: string)?.standarizedAddress ?? string
        headerView.setContent(destination)
        return false
    }
    
}
