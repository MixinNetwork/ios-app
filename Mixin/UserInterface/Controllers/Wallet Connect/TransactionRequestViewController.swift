import UIKit
import BigInt
import web3
import Web3Wallet
import MixinServices

final class TransactionRequestViewController: AuthenticationPreviewViewController {
    
    private let address: String
    private let session: WalletConnectSession
    private let request: WalletConnectSign.Request
    private let transactionPreview: WalletConnectTransactionPreview
    private let chain: WalletConnectService.Chain
    private let chainToken: TokenItem
    private let client: EthereumHttpClient
    
    private var fee: Fee?
    
    private var transaction: EthereumTransaction?
    private var account: EthereumAccount?
    private var hasTransactionSent = false
    
    init(
        address: String,
        session: WalletConnectSession,
        request: WalletConnectSign.Request,
        transaction: WalletConnectTransactionPreview,
        chain: WalletConnectService.Chain,
        chainToken: TokenItem
    ) {
        self.address = address
        self.session = session
        self.request = request
        self.transactionPreview = transaction
        self.chain = chain
        self.chainToken = chainToken
        self.client = chain.makeEthereumClient()
        let canDecodeValue = (transaction.decimalValue ?? 0) != 0
        let warnings: [String] = if canDecodeValue {
            []
        } else {
            [R.string.localizable.decode_transaction_failed()]
        }
        super.init(warnings: warnings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        Logger.web3.debug(category: "TxRequest", message: "\(self) deinited")
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
            .info(caption: .account, content: address),
            .info(caption: .network, content: chain.name)
        ]
        let transactionRow: Row
        if let tokenValue = transactionPreview.decimalValue, tokenValue != 0 {
            let tokenAmount = CurrencyFormatter.localizedString(from: tokenValue, format: .precision, sign: .never)
            let fiatMoneyValue = tokenValue * chainToken.decimalUSDPrice * Currency.current.decimalRate
            let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            transactionRow = .web3Amount(caption: R.string.localizable.estimated_balance_change(),
                                         tokenAmount: tokenAmount,
                                         fiatMoneyAmount: fiatMoneyAmount,
                                         token: chainToken)
        } else {
            transactionRow = .web3Message(caption: R.string.localizable.transaction(),
                                          message: transactionPreview.hexData ?? "")
        }
        rows.insert(transactionRow, at: 0)
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
        case let .web3Message(_, message):
            let preview = R.nib.textPreviewView(withOwner: nil)!
            preview.textView.text = message
            preview.show(on: AppDelegate.current.mainWindow)
        default:
            break
        }
    }
    
    override func performAction(with pin: String) {
        guard let fee = fee else {
            return
        }
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.web3_signing()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [chain, transactionPreview] in
            let account: EthereumAccount
            let transaction: EthereumTransaction
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                account = try EthereumAccount(keyStorage: keyStorage)
                guard transactionPreview.from == account.address else {
                    throw TransactionRequestError.mismatchedAddress
                }
                transaction = EthereumTransaction(from: account.address,
                                                  to: transactionPreview.to,
                                                  value: transactionPreview.value ?? 0,
                                                  data: transactionPreview.data,
                                                  nonce: nil,
                                                  gasPrice: fee.gasPrice,
                                                  gasLimit: fee.gasLimit,
                                                  chainId: chain.id)
            } catch {
                Logger.web3.error(category: "TxRequest", message: "Failed to sign: \(error)")
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
                return
            }
            await self.send(transaction: transaction, with: account)
        }
    }
    
}

extension TransactionRequestViewController {
    
    private struct Fee {
        
        let gasLimit: BigUInt
        let gasPrice: BigUInt // Wei
        let feeValue: String
        let feeCost: String
        
        init?(gasLimit: BigUInt, gasPrice: BigUInt, tokenPrice: Decimal) {
            guard let weiFee = Decimal(string: (gasLimit * gasPrice).description, locale: .enUSPOSIX) else {
                return nil
            }
            let decimalFee = weiFee * .wei
            let cost = decimalFee * tokenPrice
            
            self.gasLimit = gasLimit
            self.gasPrice = gasPrice
            self.feeValue = CurrencyFormatter.localizedString(from: decimalFee, format: .networkFee, sign: .never, symbol: nil)
            if cost >= 0.01 {
                self.feeCost = CurrencyFormatter.localizedString(from: cost, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            } else {
                self.feeCost = "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            }
        }
        
    }
    
    private enum TransactionRequestError: Error {
        case mismatchedAddress
        case invalidFee
    }
    
    @objc private func resendTransaction(_ sender: Any) {
        guard let transaction, let account else {
            return
        }
        canDismissInteractively = false
        Task.detached {
            await self.send(transaction: transaction, with: account)
        }
    }
    
    private func send(transaction: EthereumTransaction, with account: EthereumAccount) async {
        do {
            let transactionDescription = try await {
                let nonce = try await client.eth_getTransactionCount(address: account.address, block: .Pending)
                var nonceInjectedTransaction = transaction
                nonceInjectedTransaction.nonce = nonce // Make getter of `raw` happy
                if let raw = nonceInjectedTransaction.raw {
                    return raw.hexEncodedString()
                } else {
                    return transaction.jsonRepresentation ?? "(null)"
                }
            }()
            Logger.web3.info(category: "TxRequest", message: "Will send tx: \(transactionDescription)")
            let hash = try await client.eth_sendRawTransaction(transaction, withAccount: account)
            Logger.web3.info(category: "TxRequest", message: "Will respond hash: \(hash)")
            let response = RPCResult.response(AnyCodable(hash))
            try await Web3Wallet.instance.respond(topic: request.topic,
                                                  requestId: request.id,
                                                  response: response)
            await MainActor.run {
                self.hasTransactionSent = true
                self.canDismissInteractively = true
                self.tableHeaderView.setIcon(progress: .success)
                self.layoutTableHeaderView(title: R.string.localizable.web3_signing_success(),
                                           subtitle: R.string.localizable.web3_send_signature_description())
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadSingleButtonTrayView(title: R.string.localizable.done(),
                                              action:  #selector(self.close(_:)))
            }
        } catch {
            Logger.web3.error(category: "TxRequest", message: "Failed to send: \(error)")
            await MainActor.run {
                self.transaction = transaction
                self.account = account
                self.canDismissInteractively = true
                self.tableHeaderView.setIcon(progress: .failure)
                self.layoutTableHeaderView(title: R.string.localizable.web3_signing_failed(),
                                           subtitle: error.localizedDescription)
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                              leftAction: #selector(self.close(_:)),
                                              rightTitle: R.string.localizable.retry(),
                                              rightAction: #selector(self.resendTransaction(_:)),
                                              animation: .vertical)
            }
        }
    }
    
    private func loadGas() {
        var confirmButton: UIButton? {
            (trayView as? AuthenticationPreviewDoubleButtonTrayView)?.rightButton
        }
        confirmButton?.isEnabled = false
        let tokenPrice = chainToken.decimalUSDPrice * Currency.current.decimalRate
        Task { [address, client, transactionPreview, weak self] in
            do {
                let dappGasLimit = transactionPreview.gas
                let transaction = EthereumTransaction(from: EthereumAddress(address),
                                                      to: transactionPreview.to,
                                                      value: transactionPreview.value ?? 0,
                                                      data: transactionPreview.data,
                                                      nonce: nil,
                                                      gasPrice: nil,
                                                      gasLimit: nil,
                                                      chainId: nil)
                let rpcGasLimit = try await client.eth_estimateGas(transaction)
                let gasLimit: BigUInt = {
                    let value = if let dappGasLimit {
                        max(dappGasLimit, rpcGasLimit)
                    } else {
                        rpcGasLimit
                    }
                    return value + value / 2 // 1.5x gasLimit
                }()
                let gasPrice = try await client.eth_gasPrice()
                let fee = Fee(gasLimit: gasLimit,
                              gasPrice: gasPrice,
                              tokenPrice: tokenPrice)
                guard let fee else {
                    Logger.web3.error(category: "TxRequest", message: "Invalid gl: \(gasLimit.description), gp: \(gasPrice.description)")
                    throw TransactionRequestError.invalidFee
                }
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    self.fee = fee
                    self.reloadFeeRow(with: fee)
                    confirmButton?.isEnabled = true
                }
            } catch {
                try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                await MainActor.run {
                    self?.loadGas()
                }
            }
        }
    }
    
    private func rejectTransactionIfSignatureNotSent() {
        guard !hasTransactionSent else {
            return
        }
        Logger.web3.info(category: "TxRequest", message: "Rejected by dismissing")
        Task {
            let error = JSONRPCError(code: 0, message: "User rejected")
            try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: .error(error))
        }
    }
    
    private func reloadFeeRow(with selected: Fee) {
        let row: Row = .amount(caption: .fee,
                               token: selected.feeValue + " " + chain.feeSymbol,
                               fiatMoney: selected.feeCost,
                               display: .byToken,
                               boldPrimaryAmount: false)
        replaceRow(at: 1, with: row)
    }
    
}
