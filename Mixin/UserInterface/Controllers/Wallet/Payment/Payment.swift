import Foundation
import MixinServices

struct Payment {
    
    enum Context {
        case swap(SwapContext)
        case inscription(InscriptionContext)
    }
    
    let traceID: String
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    let context: Context?
    
    init(
        traceID: String, token: TokenItem, tokenAmount: Decimal, fiatMoneyAmount: Decimal,
        memo: String, context: Context? = nil
    ) {
        self.traceID = traceID
        self.token = token
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.memo = memo
        self.context = context
    }
    
    static func inscription(
        traceID: String,
        token: TokenItem,
        memo: String,
        context: InscriptionContext
    ) -> Payment {
        let fiatMoneyAmount = context.transferAmount * token.decimalUSDPrice * Currency.current.decimalRate
        return Payment(traceID: traceID,
                       token: token,
                       tokenAmount: context.transferAmount,
                       fiatMoneyAmount: fiatMoneyAmount,
                       memo: memo,
                       context: .inscription(context))
    }
    
}

// MARK: - Transfer
extension Payment {
    
    enum TransferDestination {
        
        case user(UserItem)
        case multisig(threshold: Int32, users: [UserItem])
        case mainnet(String)
        
        var debugDescription: String {
            switch self {
            case let .user(item):
                return "<TransferDestination.user \(item.userId)>"
            case let .multisig(threshold, receivers):
                return "<TransferDestination.multisig \(threshold):\(receivers.map(\.userId))>"
            case let .mainnet(address):
                return "<TransferDestination.mainnet \(address)>"
            }
        }
        
    }
    
    struct InscriptionContext: CustomStringConvertible {
        
        enum Operation: CustomStringConvertible {
            
            case transfer
            
            // When a user releases an inscription, the operation being performed is essentially a transfer of
            // corresponding tokens, with the transfer amount being less than the `outputAmount`. In this context,
            // the `amount` refers to the actual amount being transferred, while the remaining tokens are
            // returned to the user's wallet as change.
            case release(amount: Decimal)
            
            var description: String {
                switch self {
                case .transfer:
                    "transfer"
                case .release(let amount):
                    "release \(amount)"
                }
            }
            
        }
        
        enum ReleasingAmount {
            case half
            case arbitrary(Decimal)
        }
        
        let operation: Operation
        let output: Output
        let outputAmount: Decimal
        let item: InscriptionItem
        
        var description: String {
            "<InscriptionContext op: \(operation), item: \(item.inscriptionHash), output: \(outputAmount)>"
        }
        
        var transferAmount: Decimal {
            switch operation {
            case .transfer:
                outputAmount
            case .release(let amount):
                amount
            }
        }
        
        init(operation: Payment.InscriptionContext.Operation, output: Output, outputAmount: Decimal, item: InscriptionItem) {
            self.operation = operation
            self.output = output
            self.outputAmount = outputAmount
            self.item = item
        }
        
        init?(operation: Payment.InscriptionContext.Operation, output: Output, item: InscriptionItem) {
            guard let outputAmount = output.decimalAmount else {
                return nil
            }
            self.init(operation: operation, output: output, outputAmount: outputAmount, item: item)
        }
        
        static func release(amount: ReleasingAmount, output: Output, outputAmount: Decimal, item: InscriptionItem) -> InscriptionContext {
            let releaseAmount: Decimal
            switch amount {
            case .half:
                // For outputs with an `inscription_hash`, it is stipulated that their `amount` must always be greater than 1.
                // However, the convention does not specify the value of the decimal places. If the decimal places reach
                // their maximum, for instance, 1.00000001, performing division on it will cause an overflow of decimal places.
                // Therefore, only the integeral part is used for division in this case.
                let outputAmountNumber = outputAmount as NSDecimalNumber
                let integralPart = outputAmountNumber.rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart)
                releaseAmount = (integralPart as Decimal) / 2
            case .arbitrary(let amount):
                releaseAmount = amount
            }
            return InscriptionContext(operation: .release(amount: releaseAmount),
                                      output: output,
                                      outputAmount: outputAmount,
                                      item: item)
        }
        
        static func release(amount: ReleasingAmount, output: Output, item: InscriptionItem) -> InscriptionContext? {
            guard let outputAmount = output.decimalAmount else {
                return nil
            }
            return release(amount: amount, output: output, outputAmount: outputAmount, item: item)
        }
        
    }
    
    struct SwapContext {
        let receiveToken: SwappableToken
        let receiveAmount: Decimal
    }
    
    func checkPreconditions(
        transferTo destination: TransferDestination,
        reference: String?,
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (TransferPaymentOperation, [PaymentPreconditionIssue]) -> Void
    ) {
        Task {
            let preconditions: [PaymentPrecondition]
            switch destination {
            case let .user(opponent):
                switch context {
                case .inscription:
                    preconditions = [
                        NoPendingTransactionPrecondition(token: token),
                        AlreadyPaidPrecondition(traceID: traceID),
                        KnownOpponentPrecondition(opponent: opponent),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                case .swap:
                    preconditions = [
                        NoPendingTransactionPrecondition(token: token),
                        AlreadyPaidPrecondition(traceID: traceID),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                case .none:
                    preconditions = [
                        NoPendingTransactionPrecondition(token: token),
                        AlreadyPaidPrecondition(traceID: traceID),
                        DuplicationPrecondition(operation: .transfer(opponent),
                                                token: token,
                                                tokenAmount: tokenAmount,
                                                fiatMoneyAmount: fiatMoneyAmount,
                                                memo: memo),
                        LargeAmountPrecondition(token: token,
                                                tokenAmount: tokenAmount,
                                                fiatMoneyAmount: fiatMoneyAmount),
                        KnownOpponentPrecondition(opponent: opponent),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                }
            case .multisig, .mainnet:
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    AlreadyPaidPrecondition(traceID: traceID),
                    ReferenceValidityPrecondition(reference: reference),
                ]
            }
            
            switch await check(preconditions: preconditions) {
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            case .passed(let issues):
                let outputCollectionResult: OutputCollectingResult = switch context {
                case .inscription(let context):
                    if let collection = UTXOService.OutputCollection(output: context.output) {
                        .success(collection)
                    } else {
                        .failure(.description("Invalid Amount"))
                    }
                case .swap, .none:
                    await collectOutputs(kernelAssetID: token.kernelAssetID, amount: tokenAmount, on: parent)
                }
                
                switch outputCollectionResult {
                case .success(let collection):
                    let operation = switch context {
                    case let .inscription(context):
                        TransferPaymentOperation.inscription(
                            traceID: traceID,
                            spendingOutputs: collection,
                            destination: destination,
                            token: token,
                            memo: memo,
                            reference: reference,
                            context: context
                        )
                    case let .swap(context):
                        TransferPaymentOperation.swap(
                            traceID: traceID,
                            spendingOutputs: collection,
                            destination: destination,
                            token: token,
                            amount: tokenAmount,
                            memo: memo,
                            reference: reference,
                            context: context
                        )
                    case .none:
                        TransferPaymentOperation.transfer(
                            traceID: traceID,
                            spendingOutputs: collection,
                            destination: destination,
                            token: token,
                            amount: tokenAmount,
                            memo: memo,
                            reference: reference
                        )
                    }
                    await MainActor.run {
                        onSuccess(operation, issues)
                    }
                case .failure(let reason):
                    await MainActor.run {
                        onFailure(reason)
                    }
                }
            }
        }
    }
    
}

// MARK: - Withdraw
extension Payment {
    
    enum WithdrawalDestination {
        
        case address(Address)
        case temporary(TemporaryAddress)
        case web3(address: String, chain: String)
        
        var withdrawable: WithdrawableAddress {
            switch self {
            case .address(let address):
                return address
            case .temporary(let address):
                return address
            case .web3(let destination, _):
                return TemporaryAddress(destination: destination, tag: "")
            }
        }
        
        var debugDescription: String {
            switch self {
            case let .address(address):
                return "<WithdrawalDestination.address \(address.addressId)>"
            case let .temporary(address):
                return "<WithdrawalDestination.temporary \(address.destination)>"
            case let .web3(address, chain):
                return "<WithdrawalDestination.web3 \(chain) \(address)>"
            }
        }
        
    }
    
    func checkPreconditions(
        withdrawTo destination: WithdrawalDestination,
        fee: WithdrawFeeItem,
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (WithdrawPaymentOperation, [PaymentPreconditionIssue]) -> Void
    ) {
        Task {
            let preconditions: [PaymentPrecondition]
            switch destination {
            case let .address(address):
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    AddressDustPrecondition(token: token,
                                            amount: tokenAmount,
                                            address: address),
                    DuplicationPrecondition(operation: .withdraw(address),
                                            token: token,
                                            tokenAmount: tokenAmount,
                                            fiatMoneyAmount: fiatMoneyAmount,
                                            memo: memo),
                    AddressValidityPrecondition(address: address),
                ]
            case .temporary, .web3:
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    DuplicationPrecondition(operation: .withdraw(destination.withdrawable),
                                            token: token,
                                            tokenAmount: tokenAmount,
                                            fiatMoneyAmount: fiatMoneyAmount,
                                            memo: memo)
                ]
            }
            
            switch await check(preconditions: preconditions) {
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            case .passed(let issues):
                let amount: Decimal
                if fee.tokenItem.assetID == token.assetID {
                    amount = tokenAmount + fee.amount
                } else {
                    amount = tokenAmount
                }
                let result = await collectOutputs(kernelAssetID: token.kernelAssetID, amount: amount, on: parent)
                switch result {
                case .success(let collection):
                    let addressInfo: WithdrawPaymentOperation.AddressInfo?
                    let addressID: String?
                    switch destination {
                    case let .address(address):
                        addressInfo = .label(address.label)
                        addressID = address.addressId
                    case .temporary:
                        addressInfo = nil
                        addressID = nil
                    case let .web3(_, chain):
                        addressInfo = .web3Chain(chain)
                        addressID = nil
                    }
                    let operation = WithdrawPaymentOperation(traceID: traceID,
                                                             withdrawalToken: token,
                                                             withdrawalTokenAmount: tokenAmount,
                                                             withdrawalFiatMoneyAmount: fiatMoneyAmount,
                                                             withdrawalOutputs: collection,
                                                             feeToken: fee.tokenItem,
                                                             feeAmount: fee.amount,
                                                             address: destination.withdrawable,
                                                             addressInfo: addressInfo,
                                                             addressID: addressID)
                    await MainActor.run {
                        onSuccess(operation, issues)
                    }
                case .failure(let reason):
                    await MainActor.run {
                        onFailure(reason)
                    }
                }
            }
        }
    }
    
}

// MARK: - Private works
extension Payment {
    
    enum OutputCollectingResult {
        case success(UTXOService.OutputCollection)
        case failure(PaymentPreconditionFailureReason)
    }
    
    enum InscriptionError: Error, LocalizedError {
        
        case missingLocalItem
        
        var errorDescription: String? {
            "Missing Inscription"
        }
        
    }
    
    private func collectOutputs(
        kernelAssetID: String,
        amount: Decimal,
        on parent: UIViewController
    ) async -> OutputCollectingResult {
        repeat {
            let result = UTXOService.shared.collectUnspentOutputs(kernelAssetID: token.kernelAssetID, amount: amount)
            switch result {
            case .insufficientBalance:
                return .failure(.description(R.string.localizable.insufficient_balance()))
            case .outputNotConfirmed:
                let delegation = WalletHintViewController.UserRealizedDelegation()
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        delegation.onRealize = {
                            continuation.resume()
                        }
                        let hint = WalletHintViewController(content: .waitingTransaction)
                        hint.delegate = delegation
                        UIApplication.homeContainerViewController?.present(hint, animated: true)
                    }
                    let job = SyncOutputsJob()
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
                return .failure(.userCancelled)
            case .success(let outputCollection):
                return .success(outputCollection)
            case .maxSpendingCountExceeded:
                let consolidationResult = await withCheckedContinuation { continuation in
                    DispatchQueue.main.async {
                        let consolidation = ConsolidateOutputsViewController(token: token)
                        consolidation.onCompletion = { result in
                            continuation.resume(with: .success(result))
                        }
                        let auth = AuthenticationViewController(intent: consolidation)
                        parent.present(auth, animated: true)
                    }
                }
                switch consolidationResult {
                case .userCancelled:
                    return .failure(.userCancelled)
                case .success:
                    continue
                }
            }
        } while true
    }
    
    private func check(preconditions: [PaymentPrecondition]) async -> PaymentPreconditionCheckingResult {
        var issues: [PaymentPreconditionIssue] = []
        for precondition in preconditions {
            let result = await precondition.check()
            switch result {
            case .passed(let newIssues):
                issues.append(contentsOf: newIssues)
            case .failed(let reason):
                return .failed(reason)
            }
        }
        return .passed(issues)
    }
    
}
