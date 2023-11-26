import UIKit
import MixinServices
import Tip

final class TransferConfirmationViewController: UIViewController {
    
    enum Error: Swift.Error, LocalizedError {
        
        case sign(Swift.Error?)
        case invalidTransactionResponse
        
        var errorDescription: String? {
            switch self {
            case .sign(let error):
                return error?.localizedDescription ?? "Null signature"
            case .invalidTransactionResponse:
                return "INVALID TX RESP"
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
    private let returnToURL: URL?
    
    init(
        opponent: UserItem,
        token: TokenItem,
        amountDisplay: AmountIntent,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        traceID: String,
        returnToURL: URL?
    ) {
        self.opponent = opponent
        self.token = token
        self.amountDisplay = amountDisplay
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.memo = memo
        self.traceID = traceID
        self.returnToURL = returnToURL
        let nib = R.nib.transferConfirmationView
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
    
    @objc private func finish(_ sender: Any) {
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
    
    @objc private func gotoMerchant(_ sender: Any) {
        guard let url = returnToURL else {
            finish(sender)
            return
        }
        authenticationViewController?.presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.open(url)
        }
    }
    
}

extension TransferConfirmationViewController: AuthenticationIntentViewController {
    
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
        var options: AuthenticationIntentOptions = [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
        if returnToURL != nil {
            options.insert(.neverRequestAddBiometricAuthentication)
        }
        return options
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        let amount = Token.amountString(from: tokenAmount)
        let kernelAssetID = token.kernelAssetID
        let senderID = myUserId
        let receiverID = opponent.userId
        Task { [traceID] in
            do {
                Logger.general.info(category: "Transfer", message: "Transfer: \(amount) \(token.symbol), to \(opponent.userId), traceID: \(traceID)")
                
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                Logger.general.info(category: "Transfer", message: "SpendKey ready")
                
                let trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: opponent.userId, destination: nil, tag: nil)
                TraceDAO.shared.saveTrace(trace: trace)
                
                let spendingOutputs = try UTXOService.shared.collectUnspentOutputs(kernelAssetID: kernelAssetID, amount: tokenAmount)
                let spendingOutputIDs = spendingOutputs.outputs.map(\.id)
                Logger.general.info(category: "Transfer", message: "Spending \(spendingOutputs.debugDescription), id: \(spendingOutputIDs)")
                
                let ghostKeyRequests = GhostKeyRequest.transfer(receiverID: receiverID, senderID: senderID, traceID: traceID)
                let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
                let receiverGhostKey = ghostKeys[0]
                let senderGhostKey = ghostKeys[1]
                Logger.general.info(category: "Transfer", message: "GhostKeys ready")
                
                let inputsData = try spendingOutputs.encodeAsInputData()
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
                                       "",
                                       &error)
                if let error {
                    throw error
                }
                Logger.general.info(category: "Transfer", message: "Tx built")
                let inputKeys = try spendingOutputs.encodedKeys()
                let request = TransactionRequest(id: traceID, raw: tx)
                Logger.general.info(category: "Transfer", message: "Will request: \(request.id)")
                let responses = try await SafeAPI.requestTransaction(requests: [request])
                guard let response = responses.first(where: { $0.requestID == request.id }) else {
                    throw Error.invalidTransactionResponse
                }
                let viewKeys = response.views.joined(separator: ",")
                let signedTx = KernelSignTx(tx, inputKeys, viewKeys, spendKey, false, &error)
                guard let signedTx, error == nil else {
                    throw Error.sign(error)
                }
                Logger.general.info(category: "Transfer", message: "Tx signed")
                
                let now = Date().toUTCString()
                let changeOutput: Output?
                if let change = signedTx.change {
                    let output = Output(change: change,
                                        asset: kernelAssetID,
                                        mask: senderGhostKey.mask,
                                        keys: senderGhostKey.keys,
                                        lastOutput: spendingOutputs.lastOutput)
                    Logger.general.info(category: "Transfer", message: "Created change output: \(output.amount)")
                    changeOutput = output
                } else {
                    changeOutput = nil
                    Logger.general.info(category: "Transfer", message: "No change")
                }
                
                Logger.general.info(category: "Transfer", message: "Will sign: \(spendingOutputIDs)")
                let rawTransaction = RawTransaction(requestID: traceID,
                                                    rawTransaction: signedTx.raw,
                                                    receiverID: receiverID,
                                                    state: .unspent,
                                                    type: .transfer,
                                                    createdAt: now)
                OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                    try changeOutput?.save(db)
                    try rawTransaction.save(db)
                    try UTXOService.shared.updateBalance(assetID: token.assetID, kernelAssetID: kernelAssetID, db: db)
                    Logger.general.info(category: "Transfer", message: "Outputs signed")
                }
                let signedRequest = TransactionRequest(id: traceID, raw: signedTx.raw)
                Logger.general.info(category: "Transfer", message: "Will post tx: \(signedRequest.id)")
                let postResponses = try await SafeAPI.postTransaction(requests: [signedRequest])
                guard let postResponse = postResponses.first(where: { $0.requestID == signedRequest.id }) else {
                    throw Error.invalidTransactionResponse
                }
                let snapshot = SafeSnapshot(id: postResponse.snapshotID,
                                            type: .snapshot,
                                            assetID: token.assetID,
                                            amount: "-" + amount,
                                            userID: senderID,
                                            opponentID: receiverID,
                                            memo: memo.data(using: .utf8)?.hexEncodedString() ?? memo,
                                            transactionHash: signedTx.hash,
                                            createdAt: postResponse.createdAt,
                                            traceID: traceID,
                                            confirmations: nil,
                                            openingBalance: nil,
                                            closingBalance: nil,
                                            deposit: nil,
                                            withdrawal: nil)
                let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
                Logger.general.info(category: "Transfer", message: "Will sign raw txs")
                RawTransactionDAO.shared.signRawTransactions(with: [rawTransaction.requestID]) { db in
                    try snapshot.save(db)
                    try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
                    
                    if try !Conversation.exists(db, key: conversationID) {
                        let conversation = Conversation.createConversation(conversationId: conversationID,
                                                                           category: nil,
                                                                           recipientId: receiverID,
                                                                           status: ConversationStatus.START.rawValue)
                        try conversation.save(db)
                        DispatchQueue.global().async {
                            ConcurrentJobQueue.shared.addJob(job: CreateConversationJob(conversationId: conversationID))
                        }
                    }
                    try MessageDAO.shared.insertMessage(database: db, message: message, messageSource: "PeerTransfer", silentNotification: false)
                    Logger.general.info(category: "Transfer", message: "RawTx signed")
                }
                
                AppGroupUserDefaults.User.hasPerformedTransfer = true
                AppGroupUserDefaults.Wallet.defaultTransferAssetId = token.assetID
                
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    if let url = returnToURL {
                        successView.doneButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(gotoMerchant(_:)), for: .touchUpInside)
                        let stayInMixinButton = successView.insertStayInMixinButtonIfNeeded()
                        stayInMixinButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    } else {
                        successView.doneButton.setTitle(R.string.localizable.done(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    }
                    contentStackView.addArrangedSubview(successView)
                    view.layoutIfNeeded()
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "Transfer", message: "Failed to transfer: \(error)")
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
