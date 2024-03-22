import UIKit
import web3
import Web3Wallet
import MixinServices

final class SignRequestViewController: AuthenticationPreviewViewController {
    
    enum SignRequestError: Error {
        case mismatchedAddress
    }
    
    private let session: WalletConnectSession
    private let request: WalletConnectDecodedSigningRequest
    
    private var signature: String?
    private var hasSignatureSent = false
    
    init(
        session: WalletConnectSession,
        request: WalletConnectDecodedSigningRequest
    ) {
        self.session = session
        self.request = request
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
        reloadData()
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        rejectRequestIfSignatureNotSent()
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        rejectRequestIfSignatureNotSent()
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
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.web3_signing()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [request] in
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: keyStorage)
                guard account.address.toChecksumAddress().lowercased() == request.address.lowercased() else {
                    throw SignRequestError.mismatchedAddress
                }
                let signature = switch request.signable {
                case .raw(let data):
                    try account.signMessage(message: data)
                case .typed(let data):
                    try account.signMessage(message: data)
                }
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(title: R.string.localizable.web3_signing_success(),
                                               subtitle: R.string.localizable.web3_send_signature_description())
                    self.signature = signature
                    self.reloadData()
                    self.tableView.layoutIfNeeded()
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.discard(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.send(),
                                                  rightAction: #selector(self.send(_:)),
                                                  animation: .vertical)
                }
            } catch {
                Logger.web3.error(category: "Sign", message: "Failed to approve: \(error)")
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
    
}

extension SignRequestViewController {
    
    @objc private func send(_ sendButton: BusyButton) {
        guard let signature else {
            return
        }
        canDismissInteractively = false
        sendButton.isBusy = true
        let request = request.raw
        Task.detached {
            do {
                let response = RPCResult.response(AnyCodable(signature))
                try await Web3Wallet.instance.respond(topic: request.topic, requestId: request.id, response: response)
                await MainActor.run {
                    self.hasSignatureSent = true
                    self.close(sendButton)
                }
            } catch {
                Logger.web3.error(category: "Sign", message: "Failed to send: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    sendButton.isBusy = false
                    let alert = UIAlertController(title: R.string.localizable.connection_failed(),
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func reloadData() {
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        var rows: [Row] = [
            .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
            .proposer(name: session.name, host: session.host),
            .info(caption: .network, content: request.chain.name)
        ]
        if let account: String = PropertiesDAO.shared.value(forKey: .evmAccount) {
            // TODO: Get account by `self.request` if blockchain other than EVMs is supported
            rows.insert(.info(caption: .account, content: account), at: 2)
        }
        let unsignedMessage: Row = .web3Message(caption: R.string.localizable.unsigned_message(),
                                                message: request.humanReadable)
        if let signature {
            rows.insert(.web3Message(caption: R.string.localizable.signed_message(), message: signature), at: 0)
            rows.append(unsignedMessage)
        } else {
            rows.insert(unsignedMessage, at: 0)
        }
        reloadData(with: rows)
    }
    
    private func rejectRequestIfSignatureNotSent() {
        guard !hasSignatureSent else {
            return
        }
        Logger.web3.info(category: "Sign", message: "Rejected by dismissing")
        Task {
            let error = JSONRPCError(code: 0, message: "User Rejected")
            try await Web3Wallet.instance.respond(topic: request.raw.topic, requestId: request.raw.id, response: .error(error))
        }
    }
    
}
