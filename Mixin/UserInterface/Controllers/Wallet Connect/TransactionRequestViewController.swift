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
    private let chainToken: TokenItem
    
    private var feeOptions: [NetworkFeeOption] = []
    private var selectedFeeOption: NetworkFeeOption?
    
    private var transaction: EthereumTransaction?
    private var account: EthereumAccount?
    private var hasTransactionSent = false
    
    init(
        session: WalletConnectSession,
        request: WalletConnectSign.Request,
        transaction: WalletConnectTransactionPreview,
        chain: WalletConnectService.Chain,
        chainToken: TokenItem
    ) {
        self.session = session
        self.request = request
        self.transactionPreview = transaction
        self.chain = chain
        self.chainToken = chainToken
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
            .amount(caption: .fee,
                    token: R.string.localizable.calculating(),
                    fiatMoney: R.string.localizable.calculating(),
                    display: .byToken,
                    boldPrimaryAmount: false),
            .proposer(name: session.name, host: session.host),
            .info(caption: .network, content: chain.name)
        ]
        let transactionRow: Row
        if let tokenValue = transactionPreview.decimalValue {
            let tokenAmount = CurrencyFormatter.localizedString(from: tokenValue, format: .precision, sign: .never)
            let fiatMoneyValue = tokenValue * chainToken.decimalUSDPrice * Currency.current.decimalRate
            let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            transactionRow = .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                                         tokenAmount: tokenAmount,
                                         fiatMoneyAmount: fiatMoneyAmount,
                                         token: chainToken)
        } else {
            transactionRow = .web3Message(caption: R.string.localizable.transaction(),
                                          message: transactionPreview.hexData)
        }
        rows.insert(transactionRow, at: 0)
        if let account: String = PropertiesDAO.shared.value(forKey: .evmAccount) {
            // FIXME: Get account by `self.request`
            rows.insert(.info(caption: .account, content: account), at: 3)
        }
        reloadData(with: rows)
        loadGas()
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        rejectTransactionIfSignatureNotSent()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        rejectTransactionIfSignatureNotSent()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRow row: Row) {
        switch row {
        case .selectableFee:
            let selector = NetworkFeeSelectorViewController(options: feeOptions, gasSymbol: chain.gasSymbol)
            selector.delegate = self
            present(selector, animated: true)
        default:
            break
        }
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
                    self.account = account
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
                    self.transaction = nil
                    self.account = nil
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
    
}

extension TransactionRequestViewController: NetworkFeeSelectorViewControllerDelegate {
    
    func networkFeeSelectorViewController(_ controller: NetworkFeeSelectorViewController, didSelectOption option: NetworkFeeOption) {
        selectedFeeOption = option
        reloadFeeRow(with: option)
    }
    
}

extension TransactionRequestViewController {
    
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
        TIPAPI.tipGas(id: chain.internalID) { [gas=transactionPreview.gas, chainToken, weak self] result in
            switch result {
            case .success(let prices):
                let tokenPrice = chainToken.decimalUSDPrice * Currency.current.decimalRate
                let options = [
                    NetworkFeeOption(speed: R.string.localizable.fast(),
                                     tokenPrice: tokenPrice,
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.fastGasPrice,
                                     gasLimit: prices.gasLimit),
                    NetworkFeeOption(speed: R.string.localizable.normal(),
                                     tokenPrice: tokenPrice,
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.proposeGasPrice,
                                     gasLimit: prices.gasLimit),
                    NetworkFeeOption(speed: R.string.localizable.slow(),
                                     tokenPrice: tokenPrice,
                                     duration: "",
                                     gas: gas,
                                     gasPrice: prices.safeGasPrice,
                                     gasLimit: prices.gasLimit),
                ].compactMap({ $0 })
                if options.count == 3 {
                    let selected = options[1]
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        self.feeOptions = options
                        self.selectedFeeOption = selected
                        self.reloadFeeRow(with: selected)
                        if let confirmButton {
                            confirmButton.isBusy = false
                            confirmButton.isEnabled = true
                        }
                    }
                } else {
                    Logger.walletConnect.error(category: "TransactionRequest", message: "Invalid prices: \(prices)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.loadGas()
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
    
    private func reloadFeeRow(with selected: NetworkFeeOption) {
        guard feeOptions.count == 3 else {
            return
        }
        let row: Row = .selectableFee(speed: selected.speed,
                                      tokenAmount: selected.gasValue + " " + chain.gasSymbol,
                                      fiatMoneyAmount: selected.cost)
        replaceRow(at: 1, with: row)
    }
    
}
