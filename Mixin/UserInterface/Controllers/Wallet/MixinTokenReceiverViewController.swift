import UIKit
import MixinServices

final class MixinTokenReceiverViewController: TokenReceiverViewController {
    
    private enum Destination {
        case addressBook
        case classicWallet(chain: Web3Chain, address: Web3Address)
        case contact
    }
    
    private let token: MixinTokenItem
    
    private var destinations: [Destination] = [.addressBook, .contact]
    
    init(token: MixinTokenItem) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        headerView.load(token: token)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        if let web3Chain = Web3Chain.chain(chainID: token.chainID),
           let address = Web3AddressDAO.shared.classicWalletAddress(chainID: token.chainID)
        {
            destinations.insert(.classicWallet(chain: web3Chain, address: address), at: 1)
        }
        tableView.reloadData()
    }
    
    override func didInputEmpty() {
        tableView.dataSource = self
    }
    
    override func continueAction(inputAddress: String) {
        do {
            if try ExternalTransfer.isWithdrawalLink(raw: inputAddress, chainID: token.chainID) {
                Task { [weak self, token] in
                    do {
                        let transfer = try await ExternalTransfer(string: inputAddress)
                        if transfer.assetID != token.assetID {
                            throw TransferLinkError.invalidFormat
                        }
                        await MainActor.run {
                            self?.validateDesination(destination: transfer.destination, amount: transfer.amount)
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
                validateDesination(destination: inputAddress, amount: nil)
            }
        } catch TransferLinkError.invalidFormat {
            showError(description: R.string.localizable.invalid_payment_link())
        } catch {
            showError(description: error.localizedDescription)
        }
    }
    
    private func validateDesination(destination: String, amount: Decimal?) {
        guard let nextButton = self.nextButton else {
            return
        }
        
        guard !destination.isEmpty else {
            return
        }
        reporter.report(event: .sendRecipient, tags: ["type": "address"])
        if let amount {
            guard amount <= token.decimalBalance else {
                showError(description: R.string.localizable.insufficient_balance())
                return
            }
            AddressValidator.validateAddressAndLoadFee(
                assetID: token.assetID,
                destination: destination,
                tag: nil
            ) { [weak nextButton, weak self, token] (address, fee) in
                guard let self else {
                    return
                }
                let fiatMoneyAmount = amount * token.decimalUSDPrice
                let payment = Payment(
                    traceID: UUID().uuidString.lowercased(),
                    token: token,
                    tokenAmount: amount,
                    fiatMoneyAmount: fiatMoneyAmount,
                    memo: ""
                )
                payment.checkPreconditions(
                    withdrawTo: .temporary(address),
                    fee: fee,
                    on: self
                ) { reason in
                    nextButton?.isBusy = false
                    switch reason {
                    case .userCancelled, .loggedOut:
                        break
                    case .description(let message):
                        self.showError(description: message)
                    }
                } onSuccess: { (operation, issues) in
                    nextButton?.isBusy = false
                    let preview = WithdrawPreviewViewController(
                        issues: issues,
                        operation: operation,
                        amountDisplay: .byToken,
                        withdrawalTokenAmount: payment.tokenAmount,
                        withdrawalFiatMoneyAmount: payment.fiatMoneyAmount,
                        addressLabel: nil
                    )
                    self.present(preview, animated: true)
                }
            } onFailure: { [weak self] error in
                self?.showError(description: error.localizedDescription)
            }
        } else if let nextInput = AddressInfoInputViewController.oneTimeWithdraw(token: token, destination: destination) {
            navigationController?.pushViewController(nextInput, animated: true)
        } else {
            AddressValidator.validate(
                assetID: token.assetID,
                destination: destination,
                tag: nil
            ) { [weak nextButton, weak self] (address) in
                nextButton?.isBusy = false
                guard let self else {
                    return
                }
                let inputAmount: WithdrawInputAmountViewController
                if let address = AddressDAO.shared.getAddress(chainId: self.token.chainID, destination: address.destination, tag: address.tag) {
                    inputAmount = WithdrawInputAmountViewController(tokenItem: self.token, destination: .address(address))
                } else {
                    inputAmount = WithdrawInputAmountViewController(tokenItem: self.token, destination: .temporary(address))
                }
                self.navigationController?.pushViewController(inputAmount, animated: true)
            } onFailure: { [weak self] error in
                self?.showError(description: error.localizedDescription)
            }
        }
    }
}

extension MixinTokenReceiverViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
        let destination = destinations[indexPath.row]
        switch destination {
        case .addressBook:
            cell.iconImageView.image = R.image.token_receiver_address_book()
            cell.titleLabel.text = R.string.localizable.address_book()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.send_to_address_description()
        case .classicWallet:
            cell.iconImageView.image = R.image.token_receiver_wallet()
            cell.titleLabel.text = R.string.localizable.common_wallet()
            cell.titleTag = nil
            cell.descriptionLabel.text = R.string.localizable.send_to_other_wallet_description()
        case .contact:
            cell.iconImageView.image = R.image.token_receiver_contact()
            cell.titleLabel.text = R.string.localizable.mixin_contact()
            cell.titleTag = .free
            cell.descriptionLabel.text = R.string.localizable.send_to_contact_description()
        }
        return cell
    }
    
}

extension MixinTokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch destinations[indexPath.row] {
        case .contact:
            let selector = TransferReceiverViewController()
            selector.onSelect = { [token] (user) in
                self.dismiss(animated: true) {
                    reporter.report(event: .sendRecipient, tags: ["type": "contact"])
                    let inputAmount = TransferInputAmountViewController(
                        tokenItem: token,
                        receiver: .user(user)
                    )
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            self.present(selector, animated: true)
        case let .classicWallet(_, address):
            reporter.report(event: .sendRecipient, tags: ["type": "wallet"])
            let inputAmount = WithdrawInputAmountViewController(
                tokenItem: token,
                destination: .classicWallet(address)
            )
            navigationController?.pushViewController(inputAmount, animated: true)
        case .addressBook:
            let book = AddressBookViewController(token: token)
            book.onSelect = { [token] (address) in
                self.dismiss(animated: true) {
                    reporter.report(event: .sendRecipient, tags: ["type": "address_book"])
                    let inputAmount = WithdrawInputAmountViewController(
                        tokenItem: token,
                        destination: .address(address)
                    )
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            present(book, animated: true)
        }
    }
}
