import UIKit
import web3
import MixinServices

final class Web3TokenReceiverViewController: TokenReceiverViewController {
    
    private enum Destination {
        case addressBook
        case privacyWallet(_ mixinChainID: String)
    }
    
    private let payment: Web3SendingTokenPayment
    private let destinations: [Destination]
    
    init(payment: Web3SendingTokenPayment) {
        self.payment = payment
        self.destinations = [
            .addressBook,
            .privacyWallet(payment.chain.chainID),
        ]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let titleView = navigationItem.titleView as? NavigationTitleView {
            titleView.subtitle = R.string.localizable.common_wallet()
        }
        headerView.load(web3Token: payment.token)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func continueAction(inputAddress: String) {
        Web3AddressValidator.validate(
            string: inputAddress,
            payment: payment
        ) { [weak self] result in
            guard let self else {
                return
            }
            self.nextButton?.isBusy = false
            switch result {
            case let .address(type, address):
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    to: type,
                    address: address
                )
                let input = Web3TransferInputAmountViewController(payment: addressPayment)
                self.navigationController?.pushViewController(input, animated: true)
            case let .insufficientBalance(transferring, fee):
                let insufficient = InsufficientBalanceViewController(
                    intent: .commonWalletTransfer(transferring: transferring, fee: fee)
                )
                self.present(insufficient, animated: true)
            case let .transfer(operation, label):
                let transfer = Web3TransferPreviewViewController(
                    operation: operation,
                    proposer: .user(addressLabel: label)
                )
                transfer.manipulateNavigationStackOnFinished = true
                Web3PopupCoordinator.enqueue(popup: .request(transfer))
            case .solAmountTooSmall:
                let cost = CurrencyFormatter.localizedString(
                    from: Solana.accountCreationCost,
                    format: .precision,
                    sign: .never,
                )
                let description = R.string.localizable.send_sol_for_rent(cost)
                self.showError(description: description)
            }
        } onFailure: { [weak self] error in
            self?.showError(description: error.localizedDescription)
        }
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            destinations.count
        } else {
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTipInTransfer ? 0 : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            let destination = destinations[indexPath.row]
            switch destination {
            case .privacyWallet:
                cell.iconImageView.image = R.image.token_receiver_wallet()
                cell.titleLabel.text = R.string.localizable.privacy_wallet()
                cell.titleTag = .privacyShield
                cell.descriptionLabel.text = R.string.localizable.send_to_privacy_wallet_description()
            case .addressBook:
                cell.iconImageView.image = R.image.token_receiver_address_book()
                cell.titleLabel.text = R.string.localizable.address_book()
                cell.titleTag = nil
                cell.descriptionLabel.text = R.string.localizable.send_to_address_description()
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: walletTipReuseIdentifier, for: indexPath) as! WalletTipTableViewCell
            cell.tipView.content = .privacy
            cell.tipView.delegate = self
            return cell
        }
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }
        let destination = destinations[indexPath.row]
        switch destination {
        case .addressBook:
            reporter.report(event: .sendRecipient, tags: ["type": "address_book"])
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
        case .privacyWallet(let chainID):
            reporter.report(event: .sendRecipient, tags: ["type": "wallet"])
            sendToMyMixinWallet(chainID: chainID)
        }
    }
    
}

extension Web3TokenReceiverViewController: WalletTipView.Delegate {
    
    func walletTipViewWantsToClose(_ view: WalletTipView) {
        AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTipInTransfer = true
        let indexPath = IndexPath(row: 0, section: 1)
        tableView.deleteRows(at: [indexPath], with: .fade)
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
