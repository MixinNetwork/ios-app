import UIKit
import web3
import MixinServices

final class Web3TokenReceiverViewController: TokenReceiverViewController {
    
    private enum Receiver {
        case addressBook
        case contact
        case myWallets
    }
    
    private let payment: Web3SendingTokenPayment
    private let receivers: [Receiver] = [.addressBook, .contact, .myWallets]
    
    init(payment: Web3SendingTokenPayment) {
        self.payment = payment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.send(),
            wallet: .common(payment.wallet)
        )
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
            case let .address(address, label):
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    toAddress: address,
                    toAddressLabel: label
                )
                let input = Web3TransferInputAmountViewController(payment: addressPayment)
                self.navigationController?.pushViewController(input, animated: true)
            case let .insufficientBalance(transferring, fee):
                let insufficient = InsufficientBalanceViewController(
                    intent: .commonWalletTransfer(wallet: payment.wallet, transferring: transferring, fee: fee)
                )
                self.present(insufficient, animated: true)
            case let .transfer(operation, label):
                let transfer = Web3TransferPreviewViewController(
                    operation: operation,
                    proposer: .user(toAddressLabel: label)
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        receivers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        switch receivers[indexPath.row] {
        case .addressBook:
            cell.iconImageView.image = R.image.token_receiver_address_book()
            cell.titleLabel.text = R.string.localizable.address_book()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.send_to_address_description()
        case .contact:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.mixin_contact()
            cell.titleTag = CrossWalletTransaction.isFeeWaived ? .free : nil
            cell.descriptionLabel.text = R.string.localizable.send_to_contact_common_wallet_description()
        case .myWallets:
            cell.iconImageView.image = R.image.token_receiver_wallet()
            cell.titleLabel.text = R.string.localizable.my_wallet()
            cell.titleTag = CrossWalletTransaction.isFeeWaived ? .free : nil
            cell.descriptionLabel.text = R.string.localizable.send_to_other_wallet_description()
        }
        return cell
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch receivers[indexPath.row] {
        case .addressBook:
            reporter.report(event: .sendRecipient, tags: ["type": "address_book"])
            let token = payment.token
            let book = AddressBookViewController(token: token)
            book.onSelect = { [payment] (address) in
                self.dismiss(animated: true) {
                    let payment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        toAddress: address.destination,
                        toAddressLabel: .addressBook(address.label)
                    )
                    let inputAmount = Web3TransferInputAmountViewController(payment: payment)
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            present(book, animated: true)
        case .contact:
            reporter.report(event: .sendRecipient, tags: ["type": "contact"])
            let selector = TransferReceiverViewController()
            selector.onSelect = { [payment] user in
                self.dismiss(animated: true) {
                    let loader = LoadContactCommonWalletAddressViewController(
                        payment: payment,
                        user: user,
                        chainID: payment.chain.chainID
                    )
                    self.navigationController?.pushViewController(loader, animated: true)
                }
            }
            present(selector, animated: true)
        case .myWallets:
            reporter.report(event: .sendRecipient, tags: ["type": "wallet"])
            let selector = TransferWalletSelectorViewController(
                intent: .pickReceiver,
                excluding: .common(payment.wallet),
                supportingChainWith: payment.token.chainID
            )
            selector.delegate = self
            present(selector, animated: true)
        }
    }
    
}

extension Web3TokenReceiverViewController: TransferWalletSelectorViewController.Delegate {
    
    func transferWalletSelectorViewController(_ viewController: TransferWalletSelectorViewController, didSelectWallet wallet: Wallet) {
        switch wallet {
        case .privacy:
            sendToPrivacyWallet()
        case .common(let wallet):
            send(to: wallet)
        }
    }
    
}

extension Web3TokenReceiverViewController {
    
    private enum PaymentError: Error {
        case noValidEntry
    }
    
    private func sendToPrivacyWallet() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Task { [payment, weak self] in
            do {
                let chainID = payment.chain.chainID
                let entries = try await SafeAPI.depositEntries(
                    assetID: payment.token.assetID,
                    chainID: chainID
                )
                if let entry = entries.first(where: { $0.chainID == chainID && $0.isPrimary }) {
                    let payment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        toAddress: entry.destination,
                        toAddressLabel: .wallet(.privacy)
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
    
    private func send(to wallet: Web3Wallet) {
        let address = Web3AddressDAO.shared.address(
            walletID: wallet.walletID,
            chainID: payment.chain.chainID
        )
        guard let destination = address?.destination else {
            return
        }
        let payment = Web3SendingTokenToAddressPayment(
            payment: payment,
            toAddress: destination,
            toAddressLabel: .wallet(.common(wallet))
        )
        let input = Web3TransferInputAmountViewController(payment: payment)
        navigationController?.pushViewController(input, animated: true)
    }
    
}
