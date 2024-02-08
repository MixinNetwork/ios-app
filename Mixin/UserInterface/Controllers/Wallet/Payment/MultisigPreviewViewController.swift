import UIKit
import MixinServices
import Tip

final class MultisigPreviewViewController: PaymentPreviewViewController {
    
    enum State {
        case paid
        case signed
        case unlocked
        case pending
    }
    
    enum Error: Swift.Error, LocalizedError {
        
        case sign(Swift.Error?)
        
        var errorDescription: String? {
            switch self {
            case .sign(let error):
                return error?.localizedDescription ?? "Null signature"
            }
        }
        
    }
    
    private let requestID: String
    private let token: TokenItem
    private let amount: Decimal
    private let sendersThreshold: Int32
    private let senders: [UserItem]
    private let receiversThreshold: Int32
    private let receivers: [UserItem]
    private let rawTransaction: String
    private let viewKeys: String
    private let action: MultisigAction
    private let index: Int
    private let state: State

    init(
        requestID: String,
        token: TokenItem,
        amount: Decimal,
        sendersThreshold: Int32,
        senders: [UserItem],
        receiversThreshold: Int32,
        receivers: [UserItem],
        rawTransaction: String,
        viewKeys: String,
        action: MultisigAction,
        index: Int,
        state: State
    ) {
        self.requestID = requestID
        self.token = token
        self.amount = amount
        self.sendersThreshold = sendersThreshold
        self.senders = senders
        self.receiversThreshold = receiversThreshold
        self.receivers = receivers
        self.rawTransaction = rawTransaction
        self.viewKeys = viewKeys
        self.action = action
        self.index = index
        self.state = state
        super.init(issues: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch state {
        case .paid:
            tableHeaderView.setIcon(progress: .failure)
            tableHeaderView.titleLabel.text = switch action {
            case .sign:
                R.string.localizable.multisig_transaction()
            case .unlock:
                R.string.localizable.revoke_multisig_transaction()
            }
            tableHeaderView.subtitleLabel.text = R.string.localizable.pay_paid()
        case .signed:
            tableHeaderView.setIcon(progress: .failure)
            tableHeaderView.titleLabel.text = switch action {
            case .sign:
                R.string.localizable.multisig_transaction()
            case .unlock:
                R.string.localizable.revoke_multisig_transaction()
            }
            tableHeaderView.subtitleLabel.text = R.string.localizable.multisig_state_signed()
        case .unlocked:
            tableHeaderView.setIcon(progress: .failure)
            tableHeaderView.titleLabel.text = switch action {
            case .sign:
                R.string.localizable.multisig_transaction()
            case .unlock:
                R.string.localizable.revoke_multisig_transaction()
            }
            tableHeaderView.subtitleLabel.text = R.string.localizable.multisig_state_unlocked()
        case .pending:
            tableHeaderView.setIcon(token: token)
            switch action {
            case .sign:
                tableHeaderView.titleLabel.text = R.string.localizable.confirm_signing_multisig()
                tableHeaderView.subtitleLabel.text = R.string.localizable.review_transfer_hint()
            case .unlock:
                tableHeaderView.titleLabel.text = R.string.localizable.revoke_multisig_signature()
                tableHeaderView.subtitleLabel.text = R.string.localizable.review_transfer_hint()
            }
        }
        
        let tokenAmount = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let fiatMoneyAmount = amount * token.decimalUSDPrice * Decimal(Currency.current.rate)
        let fiatMoneyValue = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        let fee = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let rows: [Row] = [
            .amount(token: tokenAmount, fiatMoney: fiatMoneyValue, display: .byToken),
            .senders(senders, threshold: sendersThreshold),
            .receivers(receivers, threshold: receiversThreshold),
            .info(caption: .receiverWillReceive, content: tokenAmount),
            .info(caption: .network, content: token.depositNetworkName ?? ""),
            .info(caption: .fee, content: fee)
        ]
        reloadData(with: rows)
    }
    
    override func loadInitialTrayView(animated: Bool) {
        switch state {
        case .paid, .signed, .unlocked:
            loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                     action: #selector(close(_:)))
        case .pending:
            loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                     leftAction: #selector(close(_:)),
                                     rightTitle: R.string.localizable.confirm(),
                                     rightAction: #selector(confirm(_:)),
                                     animation: animated ? .vertical : nil)
        }
    }
    
    override func performAction(with pin: String) {
        tableHeaderView.setIcon(progress: .busy)
        switch action {
        case .sign:
            layoutTableHeaderView(title: R.string.localizable.sending_multisig_signature(),
                                  subtitle: R.string.localizable.multisig_signing_description())
        case .unlock:
            layoutTableHeaderView(title: R.string.localizable.revoking_multisig_signature(),
                                  subtitle: R.string.localizable.multisig_unlocking_description())
        }
        Task {
            do {
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                Logger.general.info(category: "Multisig", message: "SpendKey ready")
                
                switch action {
                case .sign:
                    var error: NSError?
                    let signature = KernelSignTransaction(rawTransaction, viewKeys, spendKey, index, false, &error)
                    guard let signature, error == nil else {
                        throw Error.sign(error)
                    }
                    let request = TransactionRequest(id: requestID, raw: signature.raw)
                    _ = try await SafeAPI.signMultisigs(id: requestID, request: request)
                case .unlock:
                    _ = try await SafeAPI.unlockMultisigs(id: requestID)
                }
                
                await MainActor.run {
                    tableHeaderView.setIcon(progress: .success)
                    switch action {
                    case .sign:
                        layoutTableHeaderView(title: R.string.localizable.multisig_signed(),
                                              subtitle: R.string.localizable.multisig_signed_description())
                    case .unlock:
                        layoutTableHeaderView(title: R.string.localizable.multisig_revoked(),
                                              subtitle: R.string.localizable.multisig_unlocked_description())
                    }
                    tableView.setContentOffset(.zero, animated: true)
                    loadSingleButtonTrayView(title: R.string.localizable.done(),
                                             action: #selector(close(_:)))
                }
            } catch {
                await MainActor.run {
                    tableHeaderView.setIcon(progress: .failure)
                    let title = switch action {
                    case .sign:
                        R.string.localizable.multisig_signing_failed()
                    case .unlock:
                        R.string.localizable.revoking_multisig_failed()
                    }
                    layoutTableHeaderView(title: title,
                                          subtitle: error.localizedDescription,
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                             leftAction: #selector(close(_:)),
                                             rightTitle: R.string.localizable.retry(),
                                             rightAction: #selector(confirm(_:)),
                                             animation: .vertical)
                }
            }
        }
    }
    
}
