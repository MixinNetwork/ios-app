import UIKit
import MixinServices
import TIP

final class MultisigPreviewViewController: AuthenticationPreviewViewController {
    
    enum State {
        case paid
        case signed
        case revoked
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
    private let token: MixinTokenItem
    private let amount: Decimal
    private let sendersThreshold: Int32
    private let senders: [UserItem]
    private let signers: Set<String>
    private let receiversThreshold: Int32
    private let receivers: [UserItem]
    private let rawTransaction: String
    private let viewKeys: String
    private let action: MultisigAction
    private let index: Int
    private let state: State
    private let safe: SafeMultisigResponse.Safe?
    
    init(
        requestID: String,
        token: MixinTokenItem,
        amount: Decimal,
        sendersThreshold: Int32,
        senders: [UserItem],
        signers: Set<String>,
        receiversThreshold: Int32,
        receivers: [UserItem],
        rawTransaction: String,
        viewKeys: String,
        action: MultisigAction,
        index: Int,
        state: State,
        safe: SafeMultisigResponse.Safe?
    ) {
        self.requestID = requestID
        self.token = token
        self.amount = amount
        self.sendersThreshold = sendersThreshold
        self.senders = senders
        self.signers = signers
        self.receiversThreshold = receiversThreshold
        self.receivers = receivers
        self.rawTransaction = rawTransaction
        self.viewKeys = viewKeys
        self.action = action
        self.index = index
        self.state = state
        self.safe = safe
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let _ = safe {
            switch state {
            case .paid:
                tableHeaderView.setIcon(progress: .success)
                tableHeaderView.titleLabel.text = R.string.localizable.transaction_approved()
                tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixinSafe) + R.string.localizable.multisig_state_paid()
            case .signed, .revoked, .pending:
                tableHeaderView.setIcon { imageView in
                    imageView.image = R.image.transaction_checklist()
                }
                switch action {
                case .sign:
                    tableHeaderView.titleLabel.text = R.string.localizable.approve_transaction()
                case .revoke:
                    tableHeaderView.titleLabel.text = R.string.localizable.reject_transaction()
                }
                tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixinSafe)
            }
        } else {
            switch state {
            case .paid:
                tableHeaderView.setIcon(progress: .success)
                tableHeaderView.titleLabel.text = R.string.localizable.multisig_signed()
                tableHeaderView.subtitleTextView.text = R.string.localizable.multisig_state_paid()
            case .signed:
                tableHeaderView.setIcon(progress: .failure)
                tableHeaderView.titleLabel.text = switch action {
                case .sign:
                    R.string.localizable.multisig_transaction()
                case .revoke:
                    R.string.localizable.revoke_multisig_transaction()
                }
                tableHeaderView.subtitleTextView.text = R.string.localizable.multisig_state_signed()
            case .revoked:
                tableHeaderView.setIcon(progress: .failure)
                tableHeaderView.titleLabel.text = switch action {
                case .sign:
                    R.string.localizable.multisig_transaction()
                case .revoke:
                    R.string.localizable.revoke_multisig_transaction()
                }
                tableHeaderView.subtitleTextView.text = R.string.localizable.multisig_state_unlocked()
            case .pending:
                tableHeaderView.setIcon(token: token)
                switch action {
                case .sign:
                    tableHeaderView.titleLabel.text = R.string.localizable.confirm_signing_multisig()
                    tableHeaderView.subtitleTextView.text = R.string.localizable.review_transfer_hint()
                case .revoke:
                    tableHeaderView.titleLabel.text = R.string.localizable.revoke_multisig_signature()
                    tableHeaderView.subtitleTextView.text = R.string.localizable.review_transfer_hint()
                }
            }
        }
        
        let tokenValue = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let fiatMoneyAmount = amount * token.decimalUSDPrice * Decimal(Currency.current.rate)
        let fiatMoneyValue = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        
        var rows: [Row]
        if let safe {
            rows = [
                .safeMultisigAmount(token: token, tokenAmount: tokenValue, fiatMoneyAmount: fiatMoneyValue),
                .info(caption: .sender, content: safe.address),
                .safe(name: safe.name, role: safe.role),
            ]
            switch safe.operation {
            case let .transaction(transaction):
                rows.insert(.addressReceivers(token, transaction.recipients), at: 2)
                if !transaction.note.isEmpty {
                    rows.append(.info(caption: .note, content: transaction.note))
                }
            case .recovery:
                break
            }
        } else {
            let signers: Set<String>? = if self.senders.count == 1 {
                nil
            } else {
                self.signers
            }
            rows = [
                .amount(caption: .amount, token: tokenValue, fiatMoney: fiatMoneyValue, display: .byToken, boldPrimaryAmount: true),
                .receivers(receivers, threshold: receiversThreshold),
                .senders(senders, multisigSigners: signers, threshold: sendersThreshold),
                .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
                .amount(caption: .total, token: tokenValue, fiatMoney: fiatMoneyValue, display: .byToken, boldPrimaryAmount: false),
                .info(caption: .network, content: token.depositNetworkName ?? ""),
            ]
        }
        
        reloadData(with: rows)
        reporter.report(event: .sendPreview)
    }
    
    override func loadInitialTrayView(animated: Bool) {
        if safe == nil {
            switch state {
            case .paid, .signed, .revoked:
                loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                         action: #selector(close(_:)))
            case .pending:
                loadDoubleButtonTrayView(
                    leftTitle: R.string.localizable.cancel(),
                    leftAction: #selector(close(_:)),
                    rightTitle: R.string.localizable.confirm(),
                    rightAction: #selector(confirm(_:)),
                    animation: animated ? .vertical : nil
                )
            }
        } else {
            switch state {
            case .paid:
                loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                         action: #selector(close(_:)))
            case .signed, .revoked, .pending:
                switch action {
                case .sign:
                    loadDoubleButtonTrayView(
                        leftTitle: R.string.localizable.cancel(),
                        leftAction: #selector(close(_:)),
                        rightTitle: R.string.localizable.approve(),
                        rightAction: #selector(confirm(_:)),
                        animation: animated ? .vertical : nil
                    )
                case .revoke:
                    loadDoubleButtonTrayView(
                        leftTitle: R.string.localizable.cancel(),
                        leftAction: #selector(close(_:)),
                        rightTitle: R.string.localizable.reject(),
                        rightAction: #selector(confirm(_:)),
                        animation: animated ? .vertical : nil
                    )
                    if let trayView = trayView as? AuthenticationPreviewDoubleButtonTrayView {
                        trayView.rightButton.backgroundColor = UIColor(displayP3RgbValue: 0xEB5757)
                    }
                }
            }
        }
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        let (title, subtitle) = switch action {
        case .sign:
            if safe == nil {
                (R.string.localizable.sending_multisig_signature(),
                 R.string.localizable.multisig_signing_description())
            } else {
                (R.string.localizable.approving_transaction(),
                 R.string.localizable.signature_request_from(.mixinSafe))
            }
        case .revoke:
            if safe == nil {
                (R.string.localizable.revoking_multisig_signature(),
                 R.string.localizable.multisig_unlocking_description())
            } else {
                (R.string.localizable.rejecting_transaction(),
                 R.string.localizable.signature_request_from(.mixinSafe))
            }
        }
        layoutTableHeaderView(title: title, subtitle: subtitle)
        replaceTrayView(with: nil, animation: .vertical)
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
                case .revoke:
                    _ = try await SafeAPI.revokeMultisigs(id: requestID)
                }
                
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    let (title, subtitle) = switch action {
                    case .sign:
                        if safe == nil {
                            (R.string.localizable.multisig_signed(),
                             R.string.localizable.multisig_signed_description())
                        } else {
                            (R.string.localizable.transaction_approved(),
                             R.string.localizable.signature_request_from(.mixinSafe))
                        }
                    case .revoke:
                        if safe == nil {
                            (R.string.localizable.multisig_revoked(),
                             R.string.localizable.multisig_unlocked_description())
                        } else {
                            (R.string.localizable.transaction_rejected(),
                             R.string.localizable.signature_request_from(.mixinSafe))
                        }
                    }
                    layoutTableHeaderView(title: title, subtitle: subtitle)
                    if safe == nil {
                        // Update checkmark of myself after changes
                        let rows: [Row] = rows.map { row in
                            switch row {
                            case .senders(let users, var signers, let threshold):
                                switch action {
                                case .sign:
                                    signers?.insert(myUserId)
                                case .revoke:
                                    signers?.remove(myUserId)
                                }
                                return .senders(users, multisigSigners: signers, threshold: threshold)
                            default:
                                return row
                            }
                        }
                        reloadData(with: rows)
                    }
                    reporter.report(event: .sendEnd)
                    tableView.setContentOffset(.zero, animated: true)
                    loadSingleButtonTrayView(title: R.string.localizable.done(),
                                             action: #selector(close(_:)))
                }
            } catch {
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    let title = switch action {
                    case .sign:
                        if safe == nil {
                            R.string.localizable.multisig_signing_failed()
                        } else {
                            R.string.localizable.approving_transaction_failed()
                        }
                    case .revoke:
                        if safe == nil {
                            R.string.localizable.revoking_multisig_failed()
                        } else {
                            R.string.localizable.rejecting_transaction_failed()
                        }
                    }
                    layoutTableHeaderView(title: title,
                                          subtitle: errorDescription,
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
