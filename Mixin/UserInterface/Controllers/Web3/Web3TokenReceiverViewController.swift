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
        
        
        headerView.load(web3Token: payment.token)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func didInputEmpty() {
        tableView.dataSource = self
    }
    
    override func continueAction(inputAddress: String) {
        let token = payment.token
        do {
            if try ExternalTransfer.isWithdrawalLink(raw: inputAddress, chainID: payment.chain.chainID) {
                Task { [weak self] in
                    do {
                        let transfer = try await ExternalTransfer(string: inputAddress) { assetKey in
                            Web3TokenDAO.shared.assetID(assetKey: assetKey)
                        } resolveAmount: { (_, amount) in
                            ExternalTransfer.resolve(atomicAmount: amount, with: Int(token.precision))
                        }
                        if transfer.assetID != token.assetID {
                            throw TransferLinkError.invalidFormat
                        }
                        await MainActor.run {
                            self?.validateDesination(destination: transfer.destination, amount: transfer.amount, isLink: true)
                        }
                    } catch {
                        guard let self else {
                            return
                        }
                        await MainActor.run {
                            switch error {
                            case TransferLinkError.alreadyPaid:
                                self.showError(description: R.string.localizable.pay_paid())
                            case TransferLinkError.assetNotFound:
                                self.showError(description: R.string.localizable.asset_not_found())
                            case let TransferLinkError.requestError(error):
                                self.showError(description: error.localizedDescription)
                            default:
                                Logger.general.error(category: "MixinTokenReceiverViewController", message: "Invalid payment: \(inputAddress)")
                                self.showError(description: R.string.localizable.invalid_payment_link())
                            }
                        }
                    }
                }
            } else {
                validateDesination(destination: inputAddress, amount: nil, isLink: false)
            }
        } catch TransferLinkError.invalidFormat {
            showError(description: R.string.localizable.invalid_payment_link())
        } catch {
            showError(description: error.localizedDescription)
        }
    }
    
    private func validateDesination(destination: String, amount: Decimal?, isLink: Bool) {
        let verifiedAddress: String?
        switch payment.chain.kind {
        case .evm:
            let ethereumAddress = EthereumAddress(destination)
            if destination.count != 42 || ethereumAddress.asNumber() == nil {
                verifiedAddress = nil
            } else {
                verifiedAddress = ethereumAddress.toChecksumAddress()
            }
        case .solana:
            if Solana.isValidPublicKey(string: destination) {
                verifiedAddress = destination
            } else {
                verifiedAddress = nil
            }
        }
        
        guard let verifiedAddress else {
            let description = if isLink {
                R.string.localizable.invalid_payment_link()
            } else {
                R.string.localizable.error_invalid_address_plain()
            }
            showError(description: description)
            return
        }
        
        let payment = Web3SendingTokenToAddressPayment(
            payment: self.payment,
            to: .arbitrary,
            address: verifiedAddress
        )
        
        if let amount, amount > 0 {
            Web3AddressValidator.validateAmountAndLoadFee(payment: payment, amount: amount) { [weak nextButton] (operation) in
                guard let nextButton else {
                    return
                }
                nextButton.isBusy = false
                
                let transfer = Web3TransferPreviewViewController(operation: operation, proposer: .web3ToAddress)
                transfer.manipulateNavigationStackOnFinished = true
                Web3PopupCoordinator.enqueue(popup: .request(transfer))
            } onFailure: { [weak self] error in
                self?.showError(description: error.localizedDescription)
            }
        } else {
            nextButton?.isBusy = false
            let input = Web3TransferInputAmountViewController(payment: payment)
            navigationController?.pushViewController(input, animated: true)
        }
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
            cell.titleTag = .privacyShield
            cell.descriptionLabel.text = R.string.localizable.send_to_other_wallet_description()
        case .addressBook:
            cell.iconImageView.image = R.image.token_receiver_address_book()
            cell.titleLabel.text = R.string.localizable.address_book()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.send_to_address_description()
        }
        return cell
    }
    
}

extension Web3TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
