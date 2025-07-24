import UIKit
import web3
import MixinServices

final class AddWalletInputAddressViewController: AddWalletInputOnChainInfoViewController {
    
    private var address: CreateWalletRequest.Address? {
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
        if Web3AddressDAO.shared.addressExists(destination: address.destination) {
            errorDescriptionLabel.text = R.string.localizable.address_already_exists()
            return
        }
        continueButton.isBusy = true
        let request = CreateWalletRequest(
            name: R.string.localizable.watch_wallet_index(1),
            category: .watchAddress,
            addresses: [address]
        )
        RouteAPI.createWallet(request, queue: .global()) { [weak self] result in
            switch result {
            case let .success(response):
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
                DispatchQueue.main.async {
                    self?.navigationController?.popToRootViewController(animated: true)
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.errorDescriptionLabel.text = error.localizedDescription
                    self.continueButton.isBusy = false
                }
            }
        }
    }
    
    override func detectInput() {
        super.detectInput()
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            address = nil
            errorDescriptionLabel.text = nil
            return
        }
        address = {
            switch selectedChain.kind {
            case .evm:
                guard input.hasPrefix("0x"), input.count == 42 else {
                    return nil
                }
                let inputAddress = EthereumAddress(input)
                guard let number = inputAddress.asNumber(), number != 0 else {
                    return nil
                }
                return .init(
                    destination: inputAddress.toChecksumAddress(),
                    chainID: ChainID.ethereum,
                    path: nil
                )
            case .solana:
                return if Solana.isValidPublicKey(string: input)  {
                    .init(destination: input, chainID: ChainID.solana, path: nil)
                } else {
                    nil
                }
            }
        }()
        if address == nil {
            errorDescriptionLabel.text = R.string.localizable.invalid_format()
        } else {
            errorDescriptionLabel.text = nil
        }
    }
    
}
