import UIKit
import MixinServices
import Tip

final class WithdrawalConfirmationViewController: UIViewController {
    
    enum Error: Swift.Error, LocalizedError {
        
        case buildWithdrawalTx(Swift.Error?)
        case buildFeeTx(Swift.Error)
        case missingWithdrawalResponse
        case missingFeeResponse
        case alreadyPaid
        case signWithdrawal(Swift.Error?)
        case signFee(Swift.Error?)
        
        var errorDescription: String? {
            switch self {
            case .buildWithdrawalTx(let error):
                return error?.localizedDescription ?? "Null withdrawal tx"
            case .buildFeeTx(let error):
                return error.localizedDescription
            default:
                return localizedDescription
            }
        }
        
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    private let amountDisplay: AmountIntent
    
    private let withdrawalToken: TokenItem
    private let withdrawalTokenAmount: Decimal
    private let withdrawalFiatMoneyAmount: Decimal
    
    private let feeToken: Token
    private let feeAmount: Decimal
    
    private let address: Address
    private let traceID: String
    
    private let receiverID = "674d6776-d600-4346-af46-58e77d8df185"
    
    init(
        amountDisplay: AmountIntent,
        withdrawalToken: TokenItem,
        withdrawalTokenAmount: Decimal,
        withdrawalFiatMoneyAmount: Decimal,
        feeToken: Token,
        feeAmount: Decimal,
        address: Address,
        traceID: String
    ) {
        self.amountDisplay = amountDisplay
        self.withdrawalToken = withdrawalToken
        self.withdrawalTokenAmount = withdrawalTokenAmount
        self.withdrawalFiatMoneyAmount = withdrawalFiatMoneyAmount
        self.feeToken = feeToken
        self.feeAmount = feeAmount
        self.address = address
        self.traceID = traceID
        let nib = R.nib.withdrawalConfirmationView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.spacing = 10
        contentStackView.setCustomSpacing(4, after: amountLabel)
        assetIconView.setIcon(token: withdrawalToken)
        
        let tokenAmount = CurrencyFormatter.localizedString(from: withdrawalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
        switch amountDisplay {
        case .byToken:
            amountLabel.text = tokenAmount
        case .byFiatMoney:
            amountLabel.text = CurrencyFormatter.localizedString(from: withdrawalFiatMoneyAmount, format: .fiatMoney, sign: .whenNegative, symbol: .currentCurrency)
        }
        
        let fiatMoneyAmount = CurrencyFormatter.estimatedFiatMoneyValue(amount: withdrawalFiatMoneyAmount)
        let fee = CurrencyFormatter.localizedString(from: feeAmount, format: .precision, sign: .never, symbol: .custom(feeToken.symbol))
        let feeValue = CurrencyFormatter.estimatedFiatMoneyValue(amount: feeAmount * feeToken.decimalUSDPrice * Decimal(Currency.current.rate))
        valueLabel.text = R.string.localizable.pay_withdrawal_memo(tokenAmount, fiatMoneyAmount, fee, feeValue)
    }
    
    @objc private func finish(_ sender: Any) {
        authenticationViewController?.presentingViewController?.dismiss(animated: true) {
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                if let _ = (viewControllers.last as? ContainerViewController)?.viewController as? TokenViewController {
                    break
                }
                viewControllers.removeLast()
            }
            navigation.setViewControllers(viewControllers, animated: true)
        }
    }
    
}

extension WithdrawalConfirmationViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        R.string.localizable.withdrawal_to(address.label)
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        address.fullAddress
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        let isFeeTokenDifferent = withdrawalToken.assetID != feeToken.assetID
        let amount = withdrawalTokenAmount
        let senderID = myUserId
        let threshold = 1
        let memo = ""
        
        Task { [traceID] in
            do {
                let amountString = Token.amountString(from: amount)
                let feeAmountString = Token.amountString(from: feeAmount)
                let feeTraceID = UUID.uniqueObjectIDString(traceID, "FEE")
                Logger.general.info(category: "Withdraw", message: "Withdraw: \(amount) \(withdrawalToken.symbol), fee: \(feeAmount) \(feeToken.symbol), to \(address.fullAddress), traceID: \(traceID), feeTraceID: \(feeTraceID)")
                
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                Logger.general.info(category: "Withdraw", message: "SpendKey ready")
                
                let trace = Trace(traceId: traceID, assetId: feeToken.assetID, amount: amountString, opponentId: nil, destination: address.destination, tag: address.tag)
                TraceDAO.shared.saveTrace(trace: trace)
                
                let withdrawalOutputs: UTXOService.OutputCollection
                let feeOutputs: UTXOService.OutputCollection?
                if isFeeTokenDifferent {
                    withdrawalOutputs = try UTXOService.shared.collectUnspentOutputs(kernelAssetID: withdrawalToken.kernelAssetID, amount: amount)
                    do {
                        feeOutputs = try UTXOService.shared.collectUnspentOutputs(kernelAssetID: feeToken.kernelAssetID, amount: feeAmount)
                    } catch UTXOService.CollectingError.insufficientBalance {
                        throw MixinAPIError.insufficientFee
                    } catch {
                        throw error
                    }
                } else {
                    withdrawalOutputs = try UTXOService.shared.collectUnspentOutputs(kernelAssetID: withdrawalToken.kernelAssetID, amount: amount + feeAmount)
                    feeOutputs = nil
                }
                Logger.general.info(category: "Withdraw", message: "Spending \(withdrawalOutputs.debugDescription), fee: \(feeOutputs?.debugDescription ?? "(null)")")
                
                let ghostKeyRequests: [GhostKeyRequest]
                if isFeeTokenDifferent {
                    ghostKeyRequests = GhostKeyRequest.withdrawFee(receiverID: receiverID, senderID: senderID, traceID: traceID)
                } else {
                    ghostKeyRequests = GhostKeyRequest.withdrawSubmit(receiverID: receiverID, senderID: senderID, traceID: traceID)
                }
                let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
                let feeOutputKeys = ghostKeys[0].keys.joined(separator: ",")
                let feeOutputMask = ghostKeys[0].mask
                let changeKeys = ghostKeys[1].keys.joined(separator: ",")
                let changeMask = ghostKeys[1].mask
                Logger.general.info(category: "Withdraw", message: "GhostKeys ready")
                
                var error: NSError?
                
                let withdrawalTx = KernelBuildWithdrawalTx(withdrawalToken.kernelAssetID,
                                                           amountString,
                                                           address.destination,
                                                           address.tag,
                                                           isFeeTokenDifferent ? "" : feeAmountString,
                                                           isFeeTokenDifferent ? "" : feeOutputKeys,
                                                           isFeeTokenDifferent ? "" : feeOutputMask,
                                                           try withdrawalOutputs.encodeAsInputData(),
                                                           changeKeys,
                                                           changeMask,
                                                           memo,
                                                           &error)
                guard let withdrawalTx, error == nil else {
                    throw Error.buildWithdrawalTx(error)
                }
                Logger.general.info(category: "Withdraw", message: "Withdrawal tx built")
                
                var requests = [TransactionRequest(id: traceID, raw: withdrawalTx.raw)]
                let feeTx: String?
                if let feeOutputs {
                    let feeChangeKeys = ghostKeys[2].keys.joined(separator: ",")
                    let feeChangeMask = ghostKeys[2].mask
                    let tx = KernelBuildTx(feeToken.kernelAssetID,
                                           feeAmountString,
                                           threshold,
                                           feeOutputKeys,
                                           feeOutputMask,
                                           try feeOutputs.encodeAsInputData(),
                                           feeChangeKeys,
                                           feeChangeMask,
                                           memo,
                                           withdrawalTx.hash,
                                           &error)
                    if let error {
                        throw Error.buildFeeTx(error)
                    }
                    requests.append(TransactionRequest(id: feeTraceID, raw: tx))
                    feeTx = tx
                    Logger.general.info(category: "Withdraw", message: "Fee tx built")
                } else {
                    feeTx = nil
                }
                
                Logger.general.info(category: "Withdraw", message: "Will request: \(requests.map(\.id))")
                let responses = try await SafeAPI.requestTransaction(requests: requests)
                guard let withdrawalResponse = responses.first(where: { $0.requestID == traceID }) else {
                    throw Error.missingWithdrawalResponse
                }
                guard withdrawalResponse.state == Output.State.unspent.rawValue else {
                    throw Error.alreadyPaid
                }
                let withdrawalViews = withdrawalResponse.views.joined(separator: ",")
                let signedWithdrawal = KernelSignTx(withdrawalTx.raw,
                                                    try withdrawalOutputs.encodedKeys(),
                                                    withdrawalViews,
                                                    spendKey,
                                                    isFeeTokenDifferent,
                                                    &error)
                guard let signedWithdrawal, error == nil else {
                    throw Error.signWithdrawal(error)
                }
                Logger.general.info(category: "Withdraw", message: "Withdrawal signed")
                let now = Date().toUTCString()
                let rawRequests: [TransactionRequest]
                if let feeOutputs, let feeTx {
                    guard let feeResponse = responses.first(where: { $0.requestID == feeTraceID }) else {
                        throw Error.missingFeeResponse
                    }
                    let feeViews = feeResponse.views.joined(separator: ",")
                    let signedFee = KernelSignTx(feeTx,
                                                 try feeOutputs.encodedKeys(),
                                                 feeViews,
                                                 spendKey,
                                                 false,
                                                 &error)
                    guard let signedFee, error == nil else {
                        throw Error.signFee(error)
                    }
                    Logger.general.info(category: "Withdraw", message: "Fee signed")
                    rawRequests = [
                        TransactionRequest(id: traceID, raw: signedWithdrawal.raw),
                        TransactionRequest(id: feeTraceID, raw: signedFee.raw)
                    ]
                    let spendingOutputIDs = withdrawalOutputs.outputs.map(\.id) + feeOutputs.outputs.map(\.id)
                    let rawTransactions = [
                        RawTransaction(requestID: traceID,
                                       rawTransaction: signedWithdrawal.raw,
                                       receiverID: receiverID,
                                       state: .unspent,
                                       type: .withdrawal,
                                       createdAt: now),
                        RawTransaction(requestID: feeTraceID,
                                       rawTransaction: signedFee.raw,
                                       receiverID: receiverID,
                                       state: .unspent,
                                       type: .fee,
                                       createdAt: now),
                    ]
                    Logger.general.info(category: "Withdraw", message: "Will sign: \(spendingOutputIDs)")
                    OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                        if let change = signedWithdrawal.change {
                            let output = Output(change: change,
                                                asset: withdrawalToken.kernelAssetID,
                                                mask: ghostKeys[1].mask,
                                                keys: ghostKeys[1].keys,
                                                lastOutput: withdrawalOutputs.lastOutput)
                            try output.save(db)
                            Logger.general.info(category: "Withdraw", message: "Saved change output: \(output.amount)")
                        } else {
                            Logger.general.info(category: "Withdraw", message: "No change")
                        }
                        if let change = signedFee.change {
                            let output = Output(change: change,
                                                asset: feeToken.kernelAssetID,
                                                mask: ghostKeys[1].mask,
                                                keys: ghostKeys[2].keys,
                                                lastOutput: feeOutputs.lastOutput)
                            try output.save(db)
                            Logger.general.info(category: "Withdraw", message: "Saved fee change output: \(output.amount)")
                        } else {
                            Logger.general.info(category: "Withdraw", message: "No fee change")
                        }
                        try rawTransactions.save(db)
                        try UTXOService.shared.updateBalance(assetID: withdrawalToken.assetID,
                                                             kernelAssetID: withdrawalToken.kernelAssetID,
                                                             db: db)
                        try UTXOService.shared.updateBalance(assetID: feeToken.assetID,
                                                             kernelAssetID: feeToken.kernelAssetID,
                                                             db: db)
                        Logger.general.info(category: "Withdraw", message: "Outputs signed")
                    }
                } else {
                    rawRequests = [
                        TransactionRequest(id: traceID, raw: signedWithdrawal.raw)
                    ]
                    let spendingOutputIDs = withdrawalOutputs.outputs.map(\.id)
                    let rawTransaction = RawTransaction(requestID: traceID,
                                                        rawTransaction: signedWithdrawal.raw,
                                                        receiverID: receiverID,
                                                        state: .unspent,
                                                        type: .withdrawal,
                                                        createdAt: now)
                    Logger.general.info(category: "Withdraw", message: "Will sign: \(spendingOutputIDs)")
                    OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                        if let change = signedWithdrawal.change {
                            let output = Output(change: change,
                                                asset: withdrawalToken.kernelAssetID,
                                                mask: ghostKeys[1].mask,
                                                keys: ghostKeys[1].keys,
                                                lastOutput: withdrawalOutputs.lastOutput)
                            try output.save(db)
                            Logger.general.info(category: "Withdraw", message: "Saved change output: \(output.amount)")
                        }
                        try rawTransaction.save(db)
                        try UTXOService.shared.updateBalance(assetID: withdrawalToken.assetID,
                                                             kernelAssetID: withdrawalToken.kernelAssetID,
                                                             db: db)
                        Logger.general.info(category: "Withdraw", message: "Outputs signed")
                    }
                }
                let rawRequestIDs = rawRequests.map(\.id)
                Logger.general.info(category: "Withdraw", message: "Will post tx: \(rawRequestIDs)")
                let postResponses = try await SafeAPI.postTransaction(requests: rawRequests)
                Logger.general.info(category: "Withdraw", message: "Will sign raw txs")
                RawTransactionDAO.shared.signRawTransactions(with: rawRequestIDs) { db in
                    if let withdrawalResponse = postResponses.first(where: { $0.requestID == traceID }) {
                        let snapshotID = withdrawalResponse.snapshotID
                        try Trace.filter(key: traceID).updateAll(db, Trace.column(of: .snapshotId).set(to: snapshotID))
                        Logger.general.info(category: "Withdraw", message: "Trace updated with: \(snapshotID)")
                    }
                    Logger.general.info(category: "Withdraw", message: "RawTx signed")
                }
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    contentStackView.addArrangedSubview(successView)
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "Withdraw", message: "Failed to withdraw: \(error)")
                let action: AuthenticationViewController.RetryAction
                switch error {
                case MixinAPIError.malformedPin, MixinAPIError.incorrectPin, MixinAPIError.insufficientPool, MixinAPIError.internalServerError:
                    action = .inputPINAgain
                case MixinAPIError.notRegisteredToSafe:
                    action = .notAllowed
                default:
                    action = .notAllowed
                }
                await MainActor.run {
                    completion(.failure(error: error, retry: action))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}