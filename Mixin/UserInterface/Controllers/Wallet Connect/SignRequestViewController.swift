import UIKit
import web3
import Web3Wallet
import MixinServices

final class SignRequestViewController: AuthenticationPreviewViewController {
    
    enum SignRequestError: Error {
        case mismatchedAddress
    }
    
    private let address: String
    private let session: WalletConnectSession
    private let request: WalletConnectDecodedSigningRequest
    
    private var signature: String?
    private var hasSignatureSent = false
    
    init(
        address: String,
        session: WalletConnectSession,
        request: WalletConnectDecodedSigningRequest
    ) {
        self.address = address
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
        layoutTableHeaderView(title: R.string.localizable.web3_message_request(),
                              subtitle: R.string.localizable.web3_ensure_trust())
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        reloadData(with: [
            .web3Message(caption: R.string.localizable.unsigned_message(), message: request.humanReadable),
            .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
            .proposer(name: session.name, host: session.host),
            .info(caption: .account, content: address),
            .info(caption: .network, content: request.chain.name)
        ])
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
        layoutTableHeaderView(title: R.string.localizable.web3_signing(),
                              subtitle: R.string.localizable.web3_ensure_trust())
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached { [request] in
            Logger.web3.info(category: "Sign", message: "Will sign")
            let signature: String
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: keyStorage)
                guard account.address.toChecksumAddress().lowercased() == request.address.lowercased() else {
                    throw SignRequestError.mismatchedAddress
                }
                signature = switch request.signable {
                case .raw(let data):
                    try account.signMessage(message: data)
                case .typed(let data):
                    try account.signMessage(message: data)
                }
            } catch {
                Logger.web3.error(category: "Sign", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: R.string.localizable.web3_signing_failed(),
                                               subtitle: error.localizedDescription,
                                               style: .destructive)
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.retry(),
                                                  rightAction: #selector(self.confirm(_:)),
                                                  animation: .vertical)
                }
                return
            }
            
            Logger.web3.info(category: "Sign", message: "Will send")
            await MainActor.run {
                self.layoutTableHeaderView(title: R.string.localizable.sending(),
                                           subtitle: R.string.localizable.web3_ensure_trust())
            }
            await self.send(signature: signature)
        }
    }
    
}

extension SignRequestViewController {
    
    @objc private func resendSignature(_ sender: Any) {
        guard let signature else {
            return
        }
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.sending(),
                              subtitle: R.string.localizable.web3_ensure_trust())
        replaceTrayView(with: nil, animation: .vertical)
        Logger.web3.info(category: "Sign", message: "Will resend")
        Task.detached {
            await self.send(signature: signature)
        }
    }
    
    private func send(signature: String) async {
        do {
            let response = RPCResult.response(AnyCodable(signature))
            try await Web3Wallet.instance.respond(topic: request.raw.topic,
                                                  requestId: request.raw.id,
                                                  response: response)
            Logger.web3.info(category: "Sign", message: "Signature sent")
            await MainActor.run {
                self.hasSignatureSent = true
                self.canDismissInteractively = true
                self.tableHeaderView.setIcon(progress: .success)
                self.layoutTableHeaderView(title: R.string.localizable.sending_success(),
                                           subtitle: R.string.localizable.web3_signing_message_success())
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadSingleButtonTrayView(title: R.string.localizable.done(),
                                              action:  #selector(self.close(_:)))
            }
        } catch {
            Logger.web3.error(category: "Sign", message: "Failed to send: \(error)")
            await MainActor.run {
                self.signature = signature
                self.canDismissInteractively = true
                self.tableHeaderView.setIcon(progress: .failure)
                self.layoutTableHeaderView(title: R.string.localizable.sending_failed(),
                                           subtitle: error.localizedDescription,
                                           style: .destructive)
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                              leftAction: #selector(self.close(_:)),
                                              rightTitle: R.string.localizable.retry(),
                                              rightAction: #selector(self.resendSignature(_:)),
                                              animation: .vertical)
            }
        }
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
