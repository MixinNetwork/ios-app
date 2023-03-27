import UIKit
import BigInt
import web3
import MixinServices

final class TransactionRequestViewController: WalletConnectRequestViewController {
    
    @MainActor var onSend: (() async throws -> Void)?
    
    private let transaction: WalletConnectTransactionPreview
    private let chain: WalletConnectService.Chain
    
    private var gasPrice: BigUInt?
    
    private lazy var sendTransactionView = R.nib.sendTransactionView(owner: self)!
    
    override var intentTitle: String {
        R.string.localizable.transaction_request()
    }
    
    override var signingCompletionView: UIView {
        sendTransactionView
    }
    
    init(session: WalletConnectSession, chain: WalletConnectService.Chain, transaction: WalletConnectTransactionPreview) {
        self.chain = chain
        self.transaction = transaction
        super.init(session: session)
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
        if let gasPrice {
            updateFeeLabel(gasPrice: gasPrice)
        } else {
            feeLabel.text = R.string.localizable.calculating()
        }
    }
    
    override func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        onReject?()
    }
    
    func updateFee(with gasPrice: BigUInt) {
        self.gasPrice = gasPrice
        if isViewLoaded {
            updateFeeLabel(gasPrice: gasPrice)
        }
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
    
    private func updateFeeLabel(gasPrice: BigUInt) {
        let fee = transaction.gas * gasPrice
        if var decimalFee = Decimal(string: fee.description, locale: .enUSPOSIX) {
            // FIXME: Wei to decimal
            decimalFee /= 1_000_000_000_000_000_000
            feeLabel.text = CurrencyFormatter.localizedString(from: decimalFee,
                                                              format: .precision,
                                                              sign: .never,
                                                              symbol: .custom(chain.gasSymbol))
        }
    }
    
}
