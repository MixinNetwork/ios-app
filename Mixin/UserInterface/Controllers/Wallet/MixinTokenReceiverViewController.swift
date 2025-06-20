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
        
        if let titleView = navigationItem.titleView as? NavigationTitleView {
            titleView.subtitle = R.string.localizable.privacy_wallet()
        }
        headerView.load(token: token)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        if let web3Chain = Web3Chain.chain(chainID: token.chainID),
           let address = Web3AddressDAO.shared.classicWalletAddress(chainID: token.chainID)
        {
            destinations.append(.classicWallet(chain: web3Chain, address: address))
        }
        tableView.reloadData()
    }
    
    override func continueAction(inputAddress: String) {
        AddressValidator.validate(
            string: inputAddress,
            withdrawing: token,
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .tagNeeded(input):
                self.nextButton?.isBusy = false
                self.navigationController?.pushViewController(input, animated: true)
            case let .addressVerified(token, destination):
                self.nextButton?.isBusy = false
                let inputAmount = WithdrawInputAmountViewController(tokenItem: token, destination: destination)
                self.navigationController?.pushViewController(inputAmount, animated: true)
                reporter.report(event: .sendRecipient, tags: ["type": destination.reportingType])
            case let .insufficientBalance(withdrawing, fee):
                self.nextButton?.isBusy = false
                let insufficient = InsufficientBalanceViewController(intent: .withdraw(withdrawing: withdrawing, fee: fee))
                self.present(insufficient, animated: true)
            case let .withdrawPayment(payment, destination, fee):
                payment.checkPreconditions(
                    withdrawTo: destination,
                    fee: fee,
                    on: self
                ) { reason in
                    self.nextButton?.isBusy = false
                    switch reason {
                    case .userCancelled, .loggedOut:
                        break
                    case .description(let message):
                        self.showError(description: message)
                    }
                } onSuccess: { (operation, issues) in
                    reporter.report(event: .sendRecipient, tags: ["type": destination.reportingType])
                    self.nextButton?.isBusy = false
                    let preview = WithdrawPreviewViewController(
                        issues: issues,
                        operation: operation,
                        amountDisplay: .byToken,
                    )
                    self.present(preview, animated: true)
                }
            }
        } onFailure: { [weak self] (error) in
            self?.showError(description: error.localizedDescription)
        }
    }
    
}

extension MixinTokenReceiverViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            destinations.count
        } else {
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTipInTransfer ? 0 : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            let destination = destinations[indexPath.row]
            switch destination {
            case .addressBook:
                cell.iconImageView.image = R.image.token_receiver_address_book()
                cell.titleLabel.text = R.string.localizable.address_book()
                cell.titleTag = nil
                cell.descriptionLabel.text = R.string.localizable.send_to_address_description()
            case .contact:
                cell.iconImageView.image = R.image.token_receiver_contact()
                cell.titleLabel.text = R.string.localizable.mixin_contact()
                cell.titleTag = .free
                cell.descriptionLabel.text = R.string.localizable.send_to_contact_description()
            case .classicWallet:
                cell.iconImageView.image = R.image.token_receiver_wallet()
                cell.titleLabel.text = R.string.localizable.common_wallet()
                cell.titleTag = nil
                cell.descriptionLabel.text = R.string.localizable.send_to_common_wallet_description()
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: walletTipReuseIdentifier, for: indexPath) as! WalletTipTableViewCell
            cell.tipView.content = .classic
            cell.tipView.delegate = self
            return cell
        }
    }
    
}

extension MixinTokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0 else {
            return
        }
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

extension MixinTokenReceiverViewController: WalletTipView.Delegate {
    
    func walletTipViewWantsToClose(_ view: WalletTipView) {
        AppGroupUserDefaults.Wallet.hasViewedClassicWalletTipInTransfer = true
        let indexPath = IndexPath(row: 0, section: 1)
        tableView.deleteRows(at: [indexPath], with: .fade)
    }
    
}
