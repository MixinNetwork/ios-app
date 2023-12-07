import UIKit
import MixinServices
import Tip

final class TransferConfirmationViewController: UIViewController {
    
    enum Destination: CustomDebugStringConvertible {
        
        case user(UserItem)
        case multisig([UserItem])
        case mainnet(String)
        
        var debugDescription: String {
            switch self {
            case let .user(item):
                return "<Destination.user \(item.userId)>"
            case let .multisig(receivers):
                return "<Destination.multisig \(receivers.map(\.userId))>"
            case let .mainnet(address):
                return "<Destination.mainnet \(address)>"
            }
        }
        
    }
    
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
    
    var manipulateNavigationStackOnFinished = true
    
    private let destination: Destination
    private let token: TokenItem
    private let amountDisplay: AmountIntent
    private let tokenAmount: Decimal
    private let fiatMoneyAmount: Decimal
    private let memo: String
    private let traceID: String
    private let returnToURL: URL?
    
    init(
        destination: Destination,
        token: TokenItem,
        amountDisplay: AmountIntent,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        memo: String,
        traceID: String,
        returnToURL: URL?
    ) {
        self.destination = destination
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
        switch destination {
        case .multisig(let receivers):
            guard let account = LoginManager.shared.account else {
                break
            }
            let patternView = R.nib.multisigPatternView(withOwner: nil)!
            contentStackView.insertArrangedSubview(patternView, at: 0)
            switch ScreenHeight.current {
            case .short:
                contentStackView.setCustomSpacing(6, after: patternView)
            case .medium:
                contentStackView.setCustomSpacing(8, after: patternView)
            case .long, .extraLong:
                contentStackView.setCustomSpacing(16, after: patternView)
            }
            patternView.showSendersButton.addTarget(self, action: #selector(showSenders(_:)), for: .touchUpInside)
            patternView.showReceiversButton.addTarget(self, action: #selector(showReceivers(_:)), for: .touchUpInside)
            patternView.reloadData(senders: [UserItem.createUser(from: account)], receivers: receivers)
        case .user, .mainnet:
            break
        }
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
        guard manipulateNavigationStackOnFinished else {
            authenticationViewController?.presentingViewController?.dismiss(animated: true)
            return
        }
        authenticationViewController?.presentingViewController?.dismiss(animated: true) { [destination] in
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            switch destination {
            case let .user(opponent):
                if viewControllers.lazy.compactMap({ $0 as? ConversationViewController }).first?.dataSource.ownerUser?.userId == opponent.userId {
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
            case .multisig, .mainnet:
                if let lastViewController = viewControllers.last as? ContainerViewController, lastViewController.viewController is TransferOutViewController {
                    viewControllers.removeLast()
                }
                navigation.setViewControllers(viewControllers, animated: true)
            }
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
    
    @objc private func showSenders(_ sender: Any) {
        switch destination {
        case .multisig:
            guard let account = LoginManager.shared.account else {
                break
            }
            let senders = MultisigUsersViewController(title: .senders, users: [UserItem.createUser(from: account)])
            present(senders, animated: true)
        default:
            break
        }
    }
    
    @objc private func showReceivers(_ sender: Any) {
        switch destination {
        case .multisig(let receivers):
            let receivers = MultisigUsersViewController(title: .receivers, users: receivers)
            present(receivers, animated: true)
        default:
            break
        }
    }
    
}

extension TransferConfirmationViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        switch destination {
        case let .user(opponent):
            return R.string.localizable.transfer_to(opponent.fullName)
        case .multisig:
            return R.string.localizable.multisig_transaction()
        case .mainnet:
            return R.string.localizable.transfer()
        }
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        switch destination {
        case let .user(opponent):
            return opponent.isCreatedByMessenger ? opponent.identityNumber : opponent.userId
        case .multisig:
            return ""
        case let .mainnet(address):
            return address
        }
    }
    
    var options: AuthenticationIntentOptions {
        var options: AuthenticationIntentOptions = [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
        if returnToURL != nil {
            options.insert(.neverRequestAddBiometricAuthentication)
        }
        switch destination {
        case .mainnet:
            options.insert(.multipleLineSubtitle)
        default:
            break
        }
        return options
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        let kernelAssetID = token.kernelAssetID
        let senderID = myUserId
        Task { [traceID, destination] in
            do {
                let amount = Token.amountString(from: tokenAmount)
                Logger.general.info(category: "Transfer", message: "Transfer: \(amount) \(token.symbol), to \(destination.debugDescription), traceID: \(traceID)")
                
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                Logger.general.info(category: "Transfer", message: "SpendKey ready")
                
                let spendingOutputs = try UTXOService.shared.collectUnspentOutputs(kernelAssetID: kernelAssetID, amount: tokenAmount)
                let spendingOutputIDs = spendingOutputs.outputs.map(\.id)
                Logger.general.info(category: "Transfer", message: "Spending \(spendingOutputs.debugDescription), id: \(spendingOutputIDs)")
                
                let inputsData = try spendingOutputs.encodeAsInputData()
                let outputKeys = try spendingOutputs.encodedKeys()
                
                let ghostKeyRequests: [GhostKeyRequest]
                switch destination {
                case let .user(opponent):
                    ghostKeyRequests = GhostKeyRequest.contactTransfer(receiverIDs: [opponent.userId], senderIDs: [senderID], traceID: traceID)
                case let .multisig(receivers):
                    ghostKeyRequests = GhostKeyRequest.contactTransfer(receiverIDs: receivers.map(\.userId), senderIDs: [senderID], traceID: traceID)
                case .mainnet:
                    ghostKeyRequests = GhostKeyRequest.mainnetAddressTransfer(senderID: senderID, traceID: traceID)
                }
                let ghostKeys = try await SafeAPI.ghostKeys(requests: ghostKeyRequests)
                let changeGhostKey = ghostKeys.last!
                Logger.general.info(category: "Transfer", message: "GhostKeys ready")
                
                var error: NSError?
                let tx: String
                switch destination {
                case .user, .multisig:
                    let receiverGhostKey = ghostKeys[0]
                    tx = KernelBuildTx(kernelAssetID,
                                       amount,
                                       1,
                                       receiverGhostKey.keys.joined(separator: ","),
                                       receiverGhostKey.mask,
                                       inputsData,
                                       changeGhostKey.keys.joined(separator: ","),
                                       changeGhostKey.mask,
                                       memo,
                                       "",
                                       &error)
                case .mainnet(let address):
                    tx = KernelBuildTxToKernelAddress(kernelAssetID,
                                                      amount,
                                                      address,
                                                      inputsData,
                                                      changeGhostKey.keys.joined(separator: ","),
                                                      changeGhostKey.mask,
                                                      memo,
                                                      &error)
                }
                if let error {
                    throw error
                }
                Logger.general.info(category: "Transfer", message: "Tx built")
                
                let request = TransactionRequest(id: traceID, raw: tx)
                Logger.general.info(category: "Transfer", message: "Will request: \(request.id)")
                let responses = try await SafeAPI.requestTransaction(requests: [request])
                guard let response = responses.first(where: { $0.requestID == request.id }) else {
                    throw Error.invalidTransactionResponse
                }
                let viewKeys = response.views.joined(separator: ",")
                let signedTx = KernelSignTx(tx, outputKeys, viewKeys, spendKey, false, &error)
                guard let signedTx, error == nil else {
                    throw Error.sign(error)
                }
                Logger.general.info(category: "Transfer", message: "Tx signed")
                
                let now = Date().toUTCString()
                let changeOutput: Output?
                if let change = signedTx.change {
                    let output = Output(change: change,
                                        asset: kernelAssetID,
                                        mask: changeGhostKey.mask,
                                        keys: changeGhostKey.keys,
                                        lastOutput: spendingOutputs.lastOutput)
                    Logger.general.info(category: "Transfer", message: "Created change output: \(output.amount)")
                    changeOutput = output
                } else {
                    changeOutput = nil
                    Logger.general.info(category: "Transfer", message: "No change")
                }
                
                Logger.general.info(category: "Transfer", message: "Will sign outputs")
                let trace: Trace?
                let rawTransactionReceiverID: String
                let snapshotOpponentID: String
                switch destination {
                case let .user(opponent):
                    trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: opponent.userId, destination: nil, tag: nil)
                    rawTransactionReceiverID = opponent.userId
                    snapshotOpponentID = opponent.userId
                case let .multisig(receivers):
                    trace = Trace(traceId: traceID, assetId: token.assetID, amount: amount, opponentId: "", destination: nil, tag: nil)
                    rawTransactionReceiverID = receivers.map(\.userId).joined(separator: ",")
                    snapshotOpponentID = ""
                case .mainnet:
                    trace = nil
                    rawTransactionReceiverID = ""
                    snapshotOpponentID = ""
                }
                let rawTransaction = RawTransaction(requestID: traceID,
                                                    rawTransaction: signedTx.raw,
                                                    receiverID: rawTransactionReceiverID,
                                                    state: .unspent,
                                                    type: .transfer,
                                                    createdAt: now)
                OutputDAO.shared.signOutputs(with: spendingOutputIDs) { db in
                    try changeOutput?.save(db)
                    try rawTransaction.save(db)
                    try trace?.save(db)
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
                                            opponentID: snapshotOpponentID,
                                            memo: memo.data(using: .utf8)?.hexEncodedString() ?? memo,
                                            transactionHash: signedTx.hash,
                                            createdAt: postResponse.createdAt,
                                            traceID: traceID,
                                            confirmations: nil,
                                            openingBalance: nil,
                                            closingBalance: nil,
                                            deposit: nil,
                                            withdrawal: nil)
                Logger.general.info(category: "Transfer", message: "Will sign raw txs")
                RawTransactionDAO.shared.signRawTransactions(with: [rawTransaction.requestID]) { db in
                    try snapshot.save(db)
                    
                    switch destination {
                    case .user(let opponent):
                        let receiverID = opponent.userId
                        try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
                        let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                        let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
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
                    case .multisig:
                        try Trace.filter(key: traceID).updateAll(db, [Trace.column(of: .snapshotId).set(to: snapshot.id)])
                    case .mainnet:
                        break
                    }
                    
                    Logger.general.info(category: "Transfer", message: "RawTx signed")
                }
                
                AppGroupUserDefaults.User.hasPerformedTransfer = true
                AppGroupUserDefaults.Wallet.defaultTransferAssetId = token.assetID
                
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    if returnToURL == nil {
                        successView.doneButton.setTitle(R.string.localizable.done(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    } else {
                        successView.doneButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(gotoMerchant(_:)), for: .touchUpInside)
                        let stayInMixinButton = successView.insertStayInMixinButtonIfNeeded()
                        stayInMixinButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
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
