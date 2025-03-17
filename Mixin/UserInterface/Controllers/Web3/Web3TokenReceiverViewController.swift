import UIKit
import web3
import MixinServices

final class Web3TokenReceiverViewController: KeyboardBasedLayoutViewController {
    
    private enum Destination {
        case privacyWallet(_ mixinChainID: String)
        case addressBook
    }
    
    private let payment: Web3SendingTokenPayment
    private let destinations: [Destination]
    private let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    private let trayViewHeight: CGFloat = 82
    
    private var verifiedAddress: String?
    
    private weak var tableView: UITableView!
    private weak var trayView: AuthenticationPreviewSingleButtonTrayView!
    
    private weak var trayViewBottomConstraint: NSLayoutConstraint!
    
    init(payment: Web3SendingTokenPayment) {
        self.payment = payment
        self.destinations = [
            .privacyWallet(payment.chain.mixinChainID),
            .addressBook,
        ]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = R.string.localizable.send()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        
        headerView.load(web3Token: payment.token)
        headerView.inputPlaceholder = R.string.localizable.hint_address()
        headerView.delegate = self
        
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background_secondary()
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 74
        tableView.tableHeaderView = headerView
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 35, right: 0)
        tableView.keyboardDismissMode = .onDrag
        
        let trayView = AuthenticationPreviewSingleButtonTrayView()
        trayView.isHidden = true
        trayView.backgroundColor = R.color.background_secondary()
        view.addSubview(trayView)
        trayView.snp.makeConstraints { make in
            make.height.equalTo(trayViewHeight)
            make.leading.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        trayView.button.setTitle(R.string.localizable.next(), for: .normal)
        trayView.button.addTarget(self, action: #selector(continueWithOneTimeAddress(_:)), for: .touchUpInside)
        let bottomConstraint = trayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomConstraint.priority = .defaultHigh
        bottomConstraint.isActive = true
        self.trayView = trayView
        self.trayViewBottomConstraint = bottomConstraint
        
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
        guard let address = verifiedAddress else {
            return
        }
        let payment = Web3SendingTokenToAddressPayment(
            payment: payment,
            to: .arbitrary,
            address: address
        )
        let input = Web3TransferInputAmountViewController(payment: payment)
        navigationController?.pushViewController(input, animated: true)
    }
    
}

extension Web3TokenReceiverViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = destinations[indexPath.row]
        switch destination {
        case .privacyWallet:
            cell.iconImageView.image = R.image.token_receiver_wallet()
            cell.titleLabel.text = R.string.localizable.privacy_wallet()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_privacy_wallet_description()
        case .addressBook:
            cell.iconImageView.image = R.image.token_receiver_address_book()
            cell.titleLabel.text = R.string.localizable.address_book()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_address_description()
        }
        return cell
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let destination = destinations[indexPath.row]
        switch destination {
        case .privacyWallet(let chainID):
            sendToMyMixinWallet(chainID: chainID)
        case .addressBook:
            let token = payment.token
            let book = AddressBookViewController(token: token)
            book.onSelect = { [payment] (address) in
                self.dismiss(animated: true) {
                    let payment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        to: .addressBook(label: address.label),
                        address: address.destination
                    )
                    let inputAmount = Web3TransferInputAmountViewController(payment: payment)
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            present(book, animated: true)
        }
    }
    
}

extension Web3TokenReceiverViewController: AddressInfoInputHeaderView.Delegate {
    
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
            trayView.isHidden = true
            verifiedAddress = nil
        } else {
            tableView.dataSource = nil
            tableView.contentInset.bottom = trayViewHeight
            trayView.isHidden = false
            let trimmedContent = headerView.trimmedContent
            switch payment.chain.kind {
            case .evm:
                let ethereumAddress = EthereumAddress(trimmedContent)
                if trimmedContent.count != 42 || ethereumAddress.asNumber() == nil {
                    verifiedAddress = nil
                } else {
                    verifiedAddress = ethereumAddress.toChecksumAddress()
                }
            case .solana:
                if Solana.isValidPublicKey(string: trimmedContent) {
                    verifiedAddress = trimmedContent
                } else {
                    verifiedAddress = nil
                }
            }
            trayView.button.isEnabled = verifiedAddress != nil
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

extension Web3TokenReceiverViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        let destination = IBANAddress(string: string)?.standarizedAddress ?? string
        headerView.setContent(destination)
        return false
    }
    
}

extension Web3TokenReceiverViewController {
    
    private enum PaymentError: Error {
        case noValidEntry
    }
    
    private func sendToMyMixinWallet(chainID: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task { [payment, weak self] in
            do {
                let entries = try await SafeAPI.depositEntries(assetID: nil, chainID: chainID)
                if let entry = entries.first(where: { $0.chainID == chainID && $0.isPrimary }) {
                    let payment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        to: .privacyWallet,
                        address: entry.destination
                    )
                    await MainActor.run {
                        guard let self else {
                            return
                        }
                        hud.hide()
                        let input = Web3TransferInputAmountViewController(payment: payment)
                        self.navigationController?.pushViewController(input, animated: true)
                    }
                } else {
                    throw PaymentError.noValidEntry
                }
            } catch {
                await MainActor.run {
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
    }
    
}
