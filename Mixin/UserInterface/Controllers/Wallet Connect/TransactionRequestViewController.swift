import UIKit
import BigInt
import web3
import MixinServices

final class TransactionRequestViewController: WalletConnectRequestViewController {
    
    @MainActor var onSend: (() async throws -> Void)?
    
    private(set) var selectedFeeOption: NetworkFeeOption?
    
    private let transaction: WalletConnectTransactionPreview
    private let chain: WalletConnectService.Chain
    
    private var feeOptions: [NetworkFeeOption] = []
    
    private lazy var sendTransactionView = R.nib.sendTransactionView(owner: self)!
    
    override var intentTitle: String {
        R.string.localizable.transaction_request()
    }
    
    override var signingCompletionView: UIView {
        sendTransactionView
    }
    
    init(
        requester: WalletConnectRequestViewController.Requester,
        chain: WalletConnectService.Chain,
        transaction: WalletConnectTransactionPreview
    ) {
        self.chain = chain
        self.transaction = transaction
        super.init(requester: requester)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let previewView = R.nib.transactionPreviewUnavailableView(owner: nil)!
        messageWrapperView.addSubview(previewView)
        previewView.snp.makeConstraints { make in
            let insets = UIEdgeInsets(top: 16, left: 16, bottom: 10, right: 16)
            make.edges.equalToSuperview().inset(insets)
        }
        chainNameLabel.text = chain.name
        feeLabel.text = R.string.localizable.calculating()
        loadGas()
    }
    
    override func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        onReject?()
    }
    
    override func changeFee(_ sender: Any) {
        let selector = NetworkFeeSelectorViewController(options: feeOptions, gasSymbol: chain.gasSymbol)
        selector.delegate = self
        present(selector, animated: true)
    }
    
    @IBAction func sendTransaction(_ sender: Any) {
        sendTransactionView.sendButton.isBusy = true
        Task {
            do {
                try await onSend?()
                await MainActor.run {
                    self.authenticationViewController?.presentingViewController?.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    Logger.walletConnect.error(category: "TransactionRequest", message: "Error: \(error)")
                    self.sendTransactionView.sendButton.isBusy = false
                    self.alert(R.string.localizable.transaction_failed(), message: "\(error)")
                }
            }
        }
    }
    
    @IBAction func discardTransaction(_ sender: Any) {
        onReject?()
        authenticationViewController?.presentingViewController?.dismiss(animated: true)
    }
    
    private func loadGas() {
        signButton.isBusy = true
        signButton.isEnabled = false
        TIPAPI.tipGas(id: chain.internalID) { [gas=transaction.gas, weak self] result in
            switch result {
            case .success(let prices):
                let options = [
                    NetworkFeeOption(speed: R.string.localizable.fast(),
                                     cost: "",
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.fastGasPrice,
                                     gasLimit: prices.gasLimit),
                    NetworkFeeOption(speed: R.string.localizable.normal(),
                                     cost: "",
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.proposeGasPrice,
                                     gasLimit: prices.gasLimit),
                    NetworkFeeOption(speed: R.string.localizable.slow(),
                                     cost: "",
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.safeGasPrice,
                                     gasLimit: prices.gasLimit),
                ].compactMap({ $0 })
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    if options.count == 3 {
                        self.feeOptions = options
                        self.selectedFeeOption = options[1]
                        self.feeButton.isEnabled = true
                        self.feeLabel.text = "\(options[1].gasValue) \(self.chain.gasSymbol)"
                        self.feeSelectorImageView.isHidden = false
                        self.signButton.isBusy = false
                        self.signButton.isEnabled = true
                    }
                }
            case .failure(let error):
                Logger.walletConnect.error(category: "TransactionRequest", message: "Failed to get gas: \(error)")
            }
        }
    }
    
}

extension TransactionRequestViewController: NetworkFeeSelectorViewControllerDelegate {
    
    func networkFeeSelectorViewController(_ controller: NetworkFeeSelectorViewController, didSelectOption option: NetworkFeeOption) {
        selectedFeeOption = option
        feeLabel.text = "\(option.gasValue) \(chain.gasSymbol)"
    }
    
}
