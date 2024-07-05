import UIKit
import MixinServices

final class Web3SwapViewController: KeyboardBasedLayoutViewController {
    
    @IBOutlet weak var payView: UIView!
    @IBOutlet weak var payStackView: UIStackView!
    @IBOutlet weak var payTitleStackView: UIStackView!
    @IBOutlet weak var payBalanceLabel: UILabel!
    @IBOutlet weak var payAmountTextField: UITextField!
    @IBOutlet weak var payIconView: BadgeIconView!
    @IBOutlet weak var paySymbolLabel: UILabel!
    @IBOutlet weak var payValueLabel: UILabel!
    
    @IBOutlet weak var receiveView: UIView!
    @IBOutlet weak var receiveBalanceLabel: UILabel!
    @IBOutlet weak var receiveAmountTextField: UITextField!
    @IBOutlet weak var receiveIconView: BadgeIconView!
    @IBOutlet weak var receiveSymbolLabel: UILabel!
    
    @IBOutlet weak var swapButton: RoundedButton!
    @IBOutlet weak var swapButtonWrapperBottomConstrait: NSLayoutConstraint!
    
    private let address: String
    private let payTokens: [Web3Token]
    private let receiveTokens: [Web3SwappableToken]
    
    private var payToken: Web3Token?
    private var receiveToken: Web3SwappableToken?
    
    init(address: String, payTokens: [Web3Token], receiveTokens: [Web3SwappableToken]) {
        self.address = address
        self.payTokens = payTokens
        self.receiveTokens = receiveTokens
        let nib = R.nib.web3SwapView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        payView.layer.masksToBounds = true
        payView.layer.cornerRadius = 8
        payStackView.setCustomSpacing(15, after: payTitleStackView)
        receiveView.layer.masksToBounds = true
        receiveView.layer.cornerRadius = 8
        if let token = payTokens.first {
            reloadPayView(with: token)
            payToken = token
        }
        receiveToken = receiveTokens.first(where: {
            // FIXME: Not same field
            $0.address != payToken?.assetKey
        })
        if let token = receiveToken {
            reloadReceiveView(with: token)
            receiveToken = token
        }
        payAmountTextField.becomeFirstResponder()
    }
    
    override func layout(for keyboardFrame: CGRect) {
        let keyboardHeight = view.bounds.height - keyboardFrame.origin.y
        swapButtonWrapperBottomConstrait.constant = keyboardHeight
        view.layoutIfNeeded()
    }
    
    @IBAction func payAmountEditingChanged(_ sender: UITextField) {
        guard
            let text = sender.text,
            let payAmount = Decimal(string: text),
            let payToken
        else {
            return
        }
        swapButton.isEnabled = payAmount > 0 && payAmount <= payToken.decimalBalance
    }
    
    @IBAction func changePayToken(_ sender: Any) {
        let selector = Web3TransferTokenSelectorViewController<Web3Token>()
        selector.onSelected = { token in
            self.payToken = token
            self.reloadPayView(with: token)
        }
        selector.reload(tokens: payTokens)
        present(selector, animated: true)
    }
    
    @IBAction func changeReceiveToken(_ sender: Any) {
        let selector = Web3TransferTokenSelectorViewController<Web3SwappableToken>()
        selector.onSelected = { token in
            self.receiveToken = token
            self.reloadReceiveView(with: token)
        }
        selector.reload(tokens: receiveTokens)
        present(selector, animated: true)
    }
    
    @IBAction func swap(_ sender: RoundedButton) {
        guard
            let payToken,
            let text = payAmountTextField.text,
            let payAmount = Decimal(string: text),
            let receiveToken,
            let request = SwapRequest(
                pay: payToken,
                payAmount: payAmount,
                payAddress: address,
                receive: receiveToken,
                slippage: 0.01
            )
        else {
            return
        }
        sender.isBusy = true
        RouteAPI.swap(request: request) { [weak self] response in
            guard let self else {
                return
            }
            sender.isBusy = false
            switch response {
            case .success(let response):
                self.requestSign(transaction: response.tx)
            case .failure(let error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    private func reloadPayView(with token: Web3Token) {
        let balance = CurrencyFormatter.localizedString(from: token.decimalBalance, format: .precision, sign: .never)
        payBalanceLabel.text = "Bal " + balance
        payIconView.setIcon(web3Token: token)
        paySymbolLabel.text = token.symbol
        payValueLabel.text = CurrencyFormatter.localizedString(from: 0, format: .fiatMoney, sign: .never)
    }
    
    private func reloadReceiveView(with token: Web3SwappableToken) {
        receiveBalanceLabel.text = nil
        receiveIconView.setIcon(web3SwappableToken: token)
        receiveSymbolLabel.text = token.symbol
        payValueLabel.text = ""
    }
    
    private func requestSign(transaction raw: String) {
        guard let homeContainer = UIApplication.homeContainerViewController else {
            return
        }
        let hud = Hud()
        hud.show(style: .busy, text: "", on: homeContainer.view)
        do {
            guard let transaction = Solana.Transaction(string: raw, encoding: .base64URL) else {
                hud.set(style: .error, text: R.string.localizable.invalid_parameters())
                hud.scheduleAutoHidden()
                return
            }
            let operation = try SolanaTransferWithCustomRespondingOperation(
                transaction: transaction,
                fromAddress: address,
                chain: .solana
            )
            hud.hide()
            let transfer = Web3TransferViewController(operation: operation, proposer: nil)
            Web3PopupCoordinator.enqueue(popup: .request(transfer))
        } catch {
            hud.set(style: .error, text: error.localizedDescription)
            hud.scheduleAutoHidden()
        }
    }
    
}
