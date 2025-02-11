import UIKit
import MixinServices

final class TokenReceiverViewController: KeyboardBasedLayoutViewController {
    
    private enum Destination {
        case contact
        case web3Wallet(chain: Web3Chain, address: String)
        case addressBook
    }
    
    private let token: TokenItem
    private let progress: UserInteractionProgress
    private let headerView = R.nib.addressInfoInputHeaderView(withOwner: nil)!
    private let trayViewHeight: CGFloat = 82
    
    private var destinations: [Destination] = [.contact, .addressBook]
    
    private weak var tableView: UITableView!
    private weak var trayView: TokenReceiverTrayView?
    
    private weak var trayViewBottomConstraint: NSLayoutConstraint?
    
    init(token: TokenItem) {
        self.token = token
        switch token.memoPossibility {
        case .positive, .possible:
            self.progress = UserInteractionProgress(currentStep: 1, totalStepCount: 3)
        case .negative:
            self.progress = UserInteractionProgress(currentStep: 1, totalStepCount: 2)
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: R.string.localizable.send(),
            subtitle: progress.description
        )
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        headerView.load(token: token)
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
        tableView.rowHeight = UITableView.automaticDimension
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
        
        if let web3Chain = Web3Chain.chain(mixinChainID: token.chainID) {
            let address: String? = switch web3Chain.kind {
            case .evm:
                PropertiesDAO.shared.unsafeValue(forKey: .evmAddress)
            case .solana:
                PropertiesDAO.shared.unsafeValue(forKey: .solanaAddress)
            }
            if let address {
                destinations.insert(.web3Wallet(chain: web3Chain, address: address), at: 1)
            }
        }
        tableView.reloadData()
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
    
    @objc private func continueWithOneTimeAddress(_ sender: StyledButton) {
        let userInput = headerView.trimmedContent
        let destination = if token.chainID == ChainID.bitcoin {
            BIP21(string: userInput)?.destination ?? userInput
        } else {
            userInput
        }
        guard !destination.isEmpty else {
            return
        }
        if let nextInput = AddressInfoInputViewController.oneTimeWithdraw(token: token, destination: destination) {
            navigationController?.pushViewController(nextInput, animated: true)
        } else {
            sender.isBusy = true
            OneTimeAddressValidator.validate(
                assetID: token.assetID,
                destination: destination,
                tag: nil
            ) { [weak sender, weak self] in
                sender?.isBusy = false
                guard let self else {
                    return
                }
                let address = TemporaryAddress(destination: destination, tag: "")
                let inputAmount = WithdrawInputAmountViewController(
                    tokenItem: self.token,
                    destination: .temporary(address),
                    progress: .init(currentStep: 2, totalStepCount: 2)
                )
                self.navigationController?.pushViewController(inputAmount, animated: true)
            } onFailure: { [weak sender, trayView] error in
                sender?.isBusy = false
                if let label = trayView?.errorDescriptionLabel {
                    label.text = error.localizedDescription
                    label.isHidden = false
                }
            }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = destinations[indexPath.row]
        switch destination {
        case .contact:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.mixin_contact()
            cell.freeLabel.isHidden = false
            cell.subtitleLabel.text = R.string.localizable.send_to_contact_description()
        case let .web3Wallet(chain, _):
            cell.iconImageView.image = R.image.token_receiver_wallet()
            cell.titleLabel.text = R.string.localizable.web3_account_network(chain.name)
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_web3_wallet_description(chain.name)
        case .addressBook:
            cell.iconImageView.image = R.image.token_receiver_address_book()
            cell.titleLabel.text = R.string.localizable.address_book()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_address_description()
        }
        return cell
    }
    
}

extension TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch destinations[indexPath.row] {
        case .contact:
            let selector = TransferReceiverViewController()
            selector.onSelect = { [token] (user) in
                self.dismiss(animated: true) {
                    let inputAmount = TransferInputAmountViewController(
                        tokenItem: token,
                        receiver: .user(user),
                        progress: .init(currentStep: 2, totalStepCount: 2)
                    )
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            self.present(selector, animated: true)
        case let .web3Wallet(chain, address):
            let inputAmount = WithdrawInputAmountViewController(
                tokenItem: token,
                destination: .web3(address: address, chain: chain.name),
                progress: .init(currentStep: 2, totalStepCount: 2)
            )
            navigationController?.pushViewController(inputAmount, animated: true)
        case .addressBook:
            let book = AddressBookViewController(token: token)
            book.onSelect = { [token] (address) in
                self.dismiss(animated: true) {
                    let inputAmount = WithdrawInputAmountViewController(
                        tokenItem: token,
                        destination: .address(address),
                        progress: .init(currentStep: 2, totalStepCount: 2)
                    )
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
