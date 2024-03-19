import UIKit
import web3
import Web3Wallet
import MixinServices

final class TransactionRequestViewController: AuthenticationPreviewViewController {
    
    enum SignRequestError: Error {
        case mismatchedAddress
    }
    
    private let session: WalletConnectSession
    private let request: WalletConnectSign.Request
    private let transactionPreview: WalletConnectTransactionPreview
    private let chain: WalletConnectService.Chain
    
    private var feeOptions: [NetworkFeeOption] = []
    private var selectedFeeOption: NetworkFeeOption?
    
    private var transaction: EthereumTransaction?
    private var account: EthereumAccount?
    private var hasTransactionSent = false
    
    init(
        session: WalletConnectSession,
        request: WalletConnectSign.Request,
        chain: WalletConnectService.Chain,
        transaction: WalletConnectTransactionPreview
    ) {
        self.session = session
        self.request = request
        self.chain = chain
        self.transactionPreview = transaction
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.setIcon { imageView in
            imageView.sd_setImage(with: session.iconURL)
        }
        layoutTableHeaderView(title: R.string.localizable.web3_signing_confirmation(),
                              subtitle: R.string.localizable.web3_signing_warning(),
                              style: .destructive)
        var rows: [Row] = [
            .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                        tokenAmount: nil,
                        fiatMoneyAmount: nil,
                        token: .xin),
            .amount(caption: .fee(speed: nil),
                    token: R.string.localizable.calculating(),
                    fiatMoney: R.string.localizable.calculating(),
                    display: .byToken,
                    boldPrimaryAmount: false),
            .proposer(name: session.name, host: session.host),
            .info(caption: .network, content: chain.name)
        ]
        if let account: String = PropertiesDAO.shared.value(forKey: .evmAccount) {
            // FIXME: Get account by `self.request`
            rows.insert(.info(caption: .account, content: account), at: 3)
        }
        reloadData(with: rows)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        rejectTransactionIfSignatureNotSent()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        rejectTransactionIfSignatureNotSent()
    }
    
    override func performAction(with pin: String) {
        guard let fee = selectedFeeOption else {
            return
        }
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.web3_signing()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [chain, transactionPreview] in
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: keyStorage)
                guard transactionPreview.from == account.address else {
                    throw SignRequestError.mismatchedAddress
                }
                let transaction = EthereumTransaction(from: nil,
                                                      to: transactionPreview.to,
                                                      value: transactionPreview.value,
                                                      data: transactionPreview.data,
                                                      nonce: nil,
                                                      gasPrice: fee.gasPrice,
                                                      gasLimit: fee.gasLimit,
                                                      chainId: chain.id)
                await MainActor.run {
                    self.transaction = transaction
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(title: R.string.localizable.web3_signing_success(),
                                               subtitle: R.string.localizable.web3_send_signature_description())
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.discard(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.send(),
                                                  rightAction: #selector(self.send(_:)),
                                                  animation: .vertical)
                }
            } catch {
                Logger.walletConnect.warn(category: "TransactionRequest", message: "Failed to approve: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: R.string.localizable.web3_signing_failed(),
                                               subtitle: error.localizedDescription)
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.retry(),
                                                  rightAction: #selector(self.confirm(_:)),
                                                  animation: .vertical)
                }
            }
        }
    }
    
    @objc private func send(_ sendButton: BusyButton) {
        guard let transaction, let account else {
            return
        }
        canDismissInteractively = false
        sendButton.isBusy = true
        Task.detached { [chain, request] in
            do {
                let network: EthereumNetwork
                switch chain {
                case .ethereum:
                    network = .mainnet
                case .sepolia:
                    network = .goerli
                default:
                    network = .custom("\(chain.id)")
                }
                Logger.walletConnect.info(category: "TransactionRequest", message: "New client with: \(chain)")
                let client = EthereumHttpClient(url: chain.rpcServerURL, network: network)
                Logger.walletConnect.debug(category: "TransactionRequest", message: "Will send raw tx: \(transaction.jsonRepresentation ?? "(null)")")
                let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
                Logger.walletConnect.debug(category: "TransactionRequest", message: "Will respond hash: \(hash)")
                let response = RPCResult.response(AnyCodable(hash))
                try await Web3Wallet.instance.respond(topic: request.topic,
                                                      requestId: request.id,
                                                      response: response)
                await MainActor.run {
                    self.close(sendButton)
                }
            } catch {
                await MainActor.run {
                    self.canDismissInteractively = true
                    sendButton.isBusy = false
                    let alert = UIAlertController(title: "Failed to Send",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func loadGas() {
        var confirmButton: BusyButton? {
            (trayView as? AuthenticationPreviewDoubleButtonTrayView)?.rightButton
        }
        if let confirmButton {
            confirmButton.isBusy = true
            confirmButton.isEnabled = false
        }
        TIPAPI.tipGas(id: chain.internalID) { [gas=transactionPreview.gas, weak self] result in
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
                        let selected = options[1]
                        self.feeOptions = options
                        self.selectedFeeOption = selected
                        let row: Row = .amount(caption: .fee(speed: selected.speed),
                                               token: "\(selected.gasValue) \(self.chain.gasSymbol)",
                                               fiatMoney: "",
                                               display: .byToken,
                                               boldPrimaryAmount: false)
                        self.replaceRow(at: 1, with: row)
                        if let confirmButton {
                            confirmButton.isBusy = false
                            confirmButton.isEnabled = true
                        }
                    }
                }
            case .failure(let error):
                Logger.walletConnect.error(category: "TransactionRequest", message: "Failed to get gas: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.loadGas()
                }
            }
        }
    }
    
    private func rejectTransactionIfSignatureNotSent() {
        guard !hasTransactionSent else {
            return
        }
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
        }
    }
    
}
