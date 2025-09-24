import UIKit
import web3
import MixinServices

final class AddWalletInputAddressViewController: AddWalletInputOnChainInfoViewController {
    
    private enum LoadAddressError: Error, LocalizedError {
        
        case invalidAddress
        case alreadyImported
        
        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                R.string.localizable.invalid_format()
            case .alreadyImported:
                R.string.localizable.wallet_already_added()
            }
        }
        
    }
    
    private var address: CreateWatchWalletRequest.Address? {
        didSet {
            continueButton.isEnabled = address != nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.add_watch_address()
        inputPlaceholderLabel.text = R.string.localizable.type_your_wallet_address()
        continueButton.configuration?.title = R.string.localizable.add()
    }
    
    override func continueToNext(_ sender: Any) {
        guard let address else {
            return
        }
        continueButton.isBusy = true
        let index = SequentialWalletNameGenerator.nextNameIndex(category: .watch)
        let request = CreateWatchWalletRequest(
            name: R.string.localizable.watch_wallet_index("\(index)"),
            addresses: [address]
        )
        RouteAPI.createWallet(request, queue: .main) { [weak self] result in
            self?.continueButton.isBusy = false
            switch result {
            case let .success(response):
                DispatchQueue.global().async {
                    Web3WalletDAO.shared.save(
                        wallets: [response.wallet],
                        addresses: response.addresses
                    )
                    let jobs = [
                        RefreshWeb3WalletTokenJob(walletID: response.wallet.walletID),
                        SyncWeb3TransactionJob(walletID: response.wallet.walletID),
                    ]
                    for job in jobs {
                        ConcurrentJobQueue.shared.addJob(job: job)
                    }
                }
                self?.navigationController?.popToRootViewController(animated: true)
            case .failure(.response(.tooManyWallets)):
                let error = AddWalletErrorViewController(error: .tooManyWatchWallets)
                self?.navigationController?.pushViewController(error, animated: true)
            case .failure(.response(.unsupportedWatchAddress)):
                let error = AddWalletErrorViewController(error: .unsupportedWatchAddress)
                error.onUseAnotherAddress = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.inputTextView.text = ""
                    self.detectInput()
                }
                self?.navigationController?.pushViewController(error, animated: true)
            case let .failure(error):
                self?.errorDescriptionLabel.text = error.localizedDescription
            }
        }
    }
    
    override func detectInput() {
        super.detectInput()
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, let importedAddresses else {
            address = nil
            errorDescriptionLabel.text = nil
            return
        }
        do {
            switch selectedChain.kind {
            case .evm:
                guard input.hasPrefix("0x"), input.count == 42 else {
                    throw LoadAddressError.invalidAddress
                }
                let inputAddress = EthereumAddress(input)
                guard let number = inputAddress.asNumber(), number != 0 else {
                    throw LoadAddressError.invalidAddress
                }
                let checksumAddress = inputAddress.toChecksumAddress()
                if importedAddresses.contains(checksumAddress) {
                    throw LoadAddressError.alreadyImported
                }
                address = .init(destination: checksumAddress, chainID: ChainID.ethereum, path: nil)
                errorDescriptionLabel.text = nil
            case .solana:
                if importedAddresses.contains(input) {
                    throw LoadAddressError.alreadyImported
                } else if Solana.isValidPublicKey(string: input)  {
                    address = .init(destination: input, chainID: ChainID.solana, path: nil)
                    errorDescriptionLabel.text = nil
                } else {
                    throw LoadAddressError.invalidAddress
                }
            }
        } catch {
            address = nil
            errorDescriptionLabel.text = error.localizedDescription
        }
    }
    
}
