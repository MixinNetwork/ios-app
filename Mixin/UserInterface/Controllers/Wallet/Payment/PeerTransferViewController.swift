import UIKit
import MixinServices
import Tip

final class PeerTransferViewController: UIViewController {
    
    enum Error: Swift.Error {
        case insufficientBalance
        case nullSignature
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
                
                var unspentOutputs = OutputDAO.shared.unspentOutputs(asset: kernelAssetID, limit: maxSpendingOutputsCount)
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
                    throw Error.insufficientBalance
                }
                Logger.general.info(category: "PeerTransfer", message: "Spending \(spendingOutputs.count) UTXOs")
                
                let ghostKeys = try await SafeAPI.ghostKeys(receiverID: receiverID,
                                                            receiverHint: UUID().uuidString.lowercased(),
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
                guard let signedTx else {
                    throw error ?? Error.nullSignature
                }
                let now = Date()
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
                                          signedAt: .distantPast,
                                          spentAt: .distantPast,
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
                _ = try await SafeAPI.postTransaction(requestID: traceID, raw: signedTx.raw)
                let snapshot = SafeSnapshot(id: "\(senderID):\(signedTx.hash)".uuidDigest(),
                                            type: SafeSnapshot.SnapshotType.snapshot.rawValue,
                                            assetID: token.assetID,
                                            amount: "-" + amount,
                                            userID: senderID,
                                            opponentID: receiverID,
                                            memo: memo,
                                            transactionHash: signedTx.hash,
                                            createdAt: now,
                                            traceID: traceID,
                                            confirmations: nil,
                                            openingBalance: nil,
                                            closingBalance: nil)
                let conversationID = ConversationDAO.shared.makeConversationId(userId: senderID, ownerUserId: receiverID)
                let message = Message.createMessage(snapshot: snapshot, conversationID: conversationID, createdAt: now)
                OutputDAO.shared.spendOutputs(with: spendingOutputIDs, raw: rawTransaction, snapshot: snapshot, message: message)
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    if let parent = authenticationViewController {
                        successView.doneButton.addTarget(parent, action: #selector(parent.close(_:)), for: .touchUpInside)
                    }
                    contentStackView.addArrangedSubview(successView)
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "PeerTransfer", message: "Failed to transfer: \(error)")
                let allowRetrying: Bool
                switch error {
                case MixinAPIError.malformedPin, MixinAPIError.incorrectPin, MixinAPIError.insufficientPool, MixinAPIError.internalServerError:
                    allowRetrying = true
                default:
                    allowRetrying = false
                }
                await MainActor.run {
                    completion(.failure(error: error, allowsRetrying: allowRetrying))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
