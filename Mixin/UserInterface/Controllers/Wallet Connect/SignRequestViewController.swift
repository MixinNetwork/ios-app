import UIKit
import web3
import Web3Wallet
import MixinServices

final class SignRequestViewController: AuthenticationPreviewViewController {
    
    enum SignRequestError: Error {
        case mismatchedAddress
    }
    
    override var authenticationTitle: String {
        R.string.localizable.continue_with_pin()
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
        layoutTableHeaderView(title: R.string.localizable.signature_request(),
                              subtitle: "我们无法验证此请求， 在发送此请求之前，请确保您信任此应用程序。",
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
            break
        default:
            break
        }
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = "正在签名"
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
                    self.signature = signature
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(title: "签名成功",
                                               subtitle: "点发送按钮立刻广播消息或点取消按钮丢弃已签名的消息。")
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.reloadData()
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.discard(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.send(),
                                                  rightAction: #selector(self.send(_:)),
                                                  animation: .vertical)
                }
            } catch {
                Logger.walletConnect.warn(category: "WalletConnectService", message: "Failed to approve: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: "连接失败",
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

extension SignRequestViewController: TextPreviewViewDelegate {
    
    func textPreviewView(_ view: TextPreviewView, didSelectURL url: URL) {
        
    }
    
    func textPreviewView(_ view: TextPreviewView, didLongPressURL url: URL) {
        
    }
    
    func textPreviewViewDidFinishPreview(_ view: TextPreviewView) {
        UIView.animate(withDuration: 0.3) {
            view.alpha = 0
        } completion: { (_) in
            view.removeFromSuperview()
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
    
    private func reloadData() {
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        var rows: [Row] = [
            .amount(caption: .fee(speed: nil), token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
            .proposer(name: session.name, host: session.host),
            .info(caption: .network, content: request.chain.name)
        ]
        if let account: String = PropertiesDAO.shared.value(forKey: .evmAccount) {
            // FIXME: Get account by `self.request`
            rows.insert(.info(caption: .account, content: account), at: 2)
        }
        let unsignedMessage: Row = .web3Message(caption: "Unsigned message", message: request.humanReadable)
        if let signature {
            rows.insert(.web3Message(caption: "SIGNED MESSAGE", message: signature), at: 0)
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
        Task {
            let error = JSONRPCError(code: 0, message: "User Rejected")
            try await Web3Wallet.instance.respond(topic: request.raw.topic, requestId: request.raw.id, response: .error(error))
        }
    }
    
    private func preview(message: String) {
        guard let view = UIApplication.homeContainerViewController?.view else {
            return
        }
        let textPreviewView = R.nib.textPreviewView(withOwner: nil)!
        textPreviewView.alpha = 0
        textPreviewView.frame = view.bounds
        view.addSubview(textPreviewView)
        view.layoutIfNeeded()
        textPreviewView.textView.text = message
        UIView.animate(withDuration: 0.3) {
            textPreviewView.alpha = 1
        }
        textPreviewView.delegate = self
    }
    
}
