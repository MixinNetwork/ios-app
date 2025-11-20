import UIKit
import MixinServices

final class MixinTokenReceiverViewController: TokenReceiverViewController {
    
    private enum Destination {
        case addressBook
        case myWallets(Web3Chain)
        case contact
    }
    
    private let token: MixinTokenItem
    private let web3Chain: Web3Chain?
    
    private var destinations: [Destination] = [.addressBook, .contact]
    
    init(token: MixinTokenItem) {
        self.token = token
        self.web3Chain = .chain(chainID: token.chainID)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.send(),
            wallet: .privacy
        )
        headerView.load(token: token)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        if let chain = web3Chain {
            destinations.append(.myWallets(chain))
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
        case .myWallets:
            cell.iconImageView.image = R.image.token_receiver_wallet()
            cell.titleLabel.text = R.string.localizable.my_wallet()
            cell.titleTag = CrossWalletTransaction.isFeeWaived ? .free : nil
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
        case .myWallets:
            reporter.report(event: .sendRecipient, tags: ["type": "wallet"])
            let selector = WalletSelectorViewController(
                intent: .pickReceiver,
                excluding: .privacy,
                supportingChainWith: token.chainID
            )
            selector.delegate = self
            present(selector, animated: true)
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

extension MixinTokenReceiverViewController: WalletSelectorViewController.Delegate {
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectWallet wallet: Wallet) {
        switch wallet {
        case .privacy:
            assertionFailure("Never transfer between Mixin Wallets through crypto network")
        case .common(let wallet):
            let address = Web3AddressDAO.shared.address(
                walletID: wallet.walletID,
                chainID: token.chainID
            )
            guard let address else {
                return
            }
            let inputAmount = WithdrawInputAmountViewController(
                tokenItem: token,
                destination: .commonWallet(wallet, address)
            )
            navigationController?.pushViewController(inputAmount, animated: true)
        }
    }
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectMultipleWallets wallets: [MixinServices.Wallet]) {
        
    }
    
}
