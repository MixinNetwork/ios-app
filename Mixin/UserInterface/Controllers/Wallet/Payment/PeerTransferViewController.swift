import UIKit
import MixinServices
import Tip

final class PeerTransferViewController: UIViewController {
    
    enum Error: Swift.Error, LocalizedError {
        
        case insufficientBalance(hasMoreOutputs: Bool)
        case sign(Swift.Error?)
        
        var errorDescription: String? {
            switch self {
            case .insufficientBalance(let hasMoreOutputs):
                if hasMoreOutputs {
                    return R.string.localizable.utxo_count_exceeded()
                } else {
                    return R.string.localizable.insufficient_balance()
                }
            case .sign(let error):
                return error?.localizedDescription ?? "Null signature"
            }
        }
        
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    
    private let opponent: UserItem
    private let token: TokenItem
    private let amountDisplay: AmountIntent
    private let tokenAmount: Decimal
    private let fiatMoneyAmount: Decimal
    private let memo: String
    private let traceID: String
    
    init(
        opponent: UserItem,
        token: TokenItem,
        amountDisplay: AmountIntent,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        traceID: String
    ) {
        self.opponent = opponent
        self.token = token
        self.amountDisplay = amountDisplay
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.memo = memo
        self.traceID = traceID
        let nib = R.nib.peerTransferView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentStackView.spacing = 10
        contentStackView.setCustomSpacing(4, after: amountLabel)
        contentStackView.setCustomSpacing(4, after: amountExchangeLabel)
        assetIconView.setIcon(token: token)
        switch amountDisplay {
        case .byToken:
            amountLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
            amountExchangeLabel.text = CurrencyFormatter.estimatedFiatMoneyValue(amount: fiatMoneyAmount)
        case .byFiatMoney:
            amountLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .whenNegative) + " " + Currency.current.code
            amountExchangeLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
        }
        memoLabel.isHidden = memo.isEmpty
        memoLabel.text = memo
    }
    
    @objc private func close(_ sender: Any) {
        let opponent = self.opponent
        authenticationViewController?.presentingViewController?.dismiss(animated: true) {
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            if (viewControllers.first(where: { $0 is ConversationViewController }) as? ConversationViewController)?.dataSource.ownerUser?.userId == opponent.userId {
                while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
                    viewControllers.removeLast()
                }
            } else {
                while (viewControllers.count > 0 && !(viewControllers.last is HomeViewController)) {
                    viewControllers.removeLast()
                }
                viewControllers.append(ConversationViewController.instance(ownerUser: opponent))
            }
            navigation.setViewControllers(viewControllers, animated: true)
        }
    }
    
}

extension PeerTransferViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        R.string.localizable.transfer_to(opponent.fullName)
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        opponent.isCreatedByMessenger ? opponent.identityNumber : opponent.userId
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        let maxSpendingOutputsCount = 256
        let amount = Token.amountString(from: tokenAmount)
        let kernelAssetID = token.kernelAssetID
        let senderID = myUserId
        let receiverID = opponent.userId
        Task {
            do {
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                let trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: opponent.userId, destination: nil, tag: nil)
                TraceDAO.shared.saveTrace(trace: trace)
                Logger.general.info(category: "PeerTransfer", message: "Will transfer \(amount)")
                
                // Select 1 more output to see if there's more outputs unspent
                var unspentOutputs = OutputDAO.shared.unspentOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount + 1)
                let hasMoreUnspentOutput = unspentOutputs.count > maxSpendingOutputsCount
                if hasMoreUnspentOutput {
                    unspentOutputs.removeLast()
                }
                
                var spendingOutputs: [Output] = []
                var spendingOutpusAmount: Decimal = 0
                while spendingOutpusAmount < tokenAmount, !unspentOutputs.isEmpty {
                    let spending = unspentOutputs.removeFirst()
                    spendingOutputs.append(spending)
                    if let spendingAmount = Decimal(string: spending.amount, locale: .enUSPOSIX) {
                        spendingOutpusAmount += spendingAmount
                    } else {
                        Logger.general.error(category: "PeerTransfer", message: "Invalid utxo.amount: \(spending.amount)")
                    }
                }
                guard let lastSpendingOutput = spendingOutputs.last, spendingOutpusAmount >= tokenAmount else {
                    throw Error.insufficientBalance(hasMoreOutputs: hasMoreUnspentOutput)
                }
                Logger.general.info(category: "PeerTransfer", message: "Spending \(spendingOutputs.count) UTXOs")
                
                let ghostKeys = try await SafeAPI.ghostKeys(receiverID: receiverID,
                                                            receiverHint: traceID,
                                                            senderID: senderID,
                                                            senderHint: UUID().uuidString.lowercased())
                let receiverGhostKey = ghostKeys[0]
                let senderGhostKey = ghostKeys[1]
                
                struct Input: Encodable {
                    let index: Int
                    let hash: String
                    let amount: String
                }
                let inputs = spendingOutputs.map { (utxo) in
                    Input(index: utxo.outputIndex, hash: utxo.transactionHash, amount: utxo.amount)
                }
                let inputsData = try JSONEncoder.default.encode(inputs)
                var error: NSError?
                let tx = KernelBuildTx(kernelAssetID,
                                       amount,
                                       1,
                                       receiverGhostKey.keys.joined(separator: ","),
                                       receiverGhostKey.mask,
                                       inputsData,
                                       senderGhostKey.keys.joined(separator: ","),
                                       senderGhostKey.mask,
                                       memo,
                                       &error)
                if let error {
                    throw error
                }
                let inputKeysData = try JSONEncoder.default.encode(spendingOutputs.map(\.keys))
                let inputKeys = String(data: inputKeysData, encoding: .utf8)
                let viewKeys = try await SafeAPI.requestTransaction(id: traceID, raw: tx, senderID: senderID).joined(separator: ",")
                let signedTx = KernelSignTx(tx, inputKeys, viewKeys, spendKey, &error)
                guard let signedTx, error == nil else {
                    throw Error.sign(error)
                }
                let now = Date().toUTCString()
                let changeOutput: Output?
                if let change = signedTx.change {
                    let outputID = "\(change.hash):\(change.index)".uuidDigest()
                    changeOutput = Output(id: outputID,
                                          transactionHash: change.hash,
                                          outputIndex: change.index,
                                          asset: kernelAssetID,
                                          amount: change.amount,
                                          mask: senderGhostKey.mask,
                                          keys: senderGhostKey.keys,
                                          receivers: [],
                                          receiversHash: "",
                                          receiversThreshold: 1,
                                          extra: "",
                                          state: Output.State.unspent.rawValue,
                                          createdAt: lastSpendingOutput.createdAt,
                                          updatedAt: now,
                                          signedBy: "",
                                          signedAt: "",
                                          spentAt: "",
                                          sequence: 0)
                } else {
                    changeOutput = nil
                }
                let spendingOutputIDs = spendingOutputs.map(\.id)
                let rawTransaction = RawTransaction(requestID: traceID,
                                                    rawTransaction: signedTx.raw,
                                                    receiverID: receiverID,
                                                    createdAt: now)
                OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                    try changeOutput?.save(db)
                    try rawTransaction.save(db)
                    try UTXOService.shared.updateBalance(assetID: token.assetID, kernelAssetID: kernelAssetID, db: db)
                }
                let transactionResponse = try await SafeAPI.postTransaction(requestID: traceID, raw: signedTx.raw)
                let snapshot = SafeSnapshot(id: "\(senderID):\(signedTx.hash)".uuidDigest(),
                                            type: SafeSnapshot.SnapshotType.snapshot.rawValue,
                                            assetID: token.assetID,
                                            amount: "-" + amount,
                                            userID: senderID,
                                            opponentID: receiverID,
                                            memo: memo,
                                            transactionHash: signedTx.hash,
                                            createdAt: transactionResponse.createdAt,
                                            traceID: traceID,
                                            confirmations: nil,
                                            openingBalance: nil,
                                            closingBalance: nil,
                                            deposit: nil,
                                            withdrawal: nil)
                let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
                OutputDAO.shared.spendOutputs(with: spendingOutputIDs) { db in
                    try snapshot.save(db)
                    try RawTransaction.deleteOne(db, key: rawTransaction.requestID)
                    try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "PeerTransfer", silentNotification: false)
                    try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
                }
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    successView.doneButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                    contentStackView.addArrangedSubview(successView)
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "PeerTransfer", message: "Failed to transfer: \(error)")
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
