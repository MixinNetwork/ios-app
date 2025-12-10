import Foundation
import MixinServices

struct Payment: PaymentPreconditionChecker {
    
    enum Context {
        case trade(TradeContext)
        case inscription(InscriptionContext)
    }
    
    let traceID: String
    let token: MixinTokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    let context: Context?
    
    init(
        traceID: String, token: MixinTokenItem, tokenAmount: Decimal, fiatMoneyAmount: Decimal,
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
        token: MixinTokenItem,
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
        
        static var storageFeeReceiver: TransferDestination {
            guard case let .mainnet(threshold, address) = MIXAddress.storageFeeReceiver else {
                fatalError("Invalid fee receiver")
            }
            return .mainnet(threshold: threshold, address: address)
        }
        
        case user(UserItem)
        case multisig(threshold: Int32, users: [UserItem])
        case mainnet(threshold: Int32, address: String)
        
        var debugDescription: String {
            switch self {
            case let .user(item):
                return "<TransferDestination.user \(item.userId)>"
            case let .multisig(threshold, receivers):
                return "<TransferDestination.multisig \(threshold):\(receivers.map(\.userId))>"
            case let .mainnet(thresold, address):
                return "<TransferDestination.mainnet \(thresold):\(address)>"
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
    
    struct TradeContext {
        
        enum Mode {
            case simple
            case advanced(TradeOrder.Expiry)
        }
        
        let mode: Mode
        let sendToken: BalancedSwapToken
        let sendAmount: Decimal
        let receiveToken: SwapToken
        let receiveAmount: Decimal
        
    }
    
    enum InscriptionError: Error, LocalizedError {
        
        case missingLocalItem
        
        var errorDescription: String? {
            "Missing Inscription"
        }
        
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
                        NoPendingTransactionPrecondition(),
                        AlreadyPaidPrecondition(traceID: traceID),
                        KnownOpponentPrecondition(opponent: opponent),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                case .trade:
                    preconditions = [
                        NoPendingTransactionPrecondition(),
                        AlreadyPaidPrecondition(traceID: traceID),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                case .none:
                    preconditions = [
                        NoPendingTransactionPrecondition(),
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
                    NoPendingTransactionPrecondition(),
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
                case .trade, .none:
                    await collectOutputs(token: token, amount: tokenAmount, on: parent)
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
                    case let .trade(context):
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
                            extra: .plain(memo),
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
        case commonWallet(Web3Wallet, any WithdrawableAddress)
        
        var withdrawable: WithdrawableAddress {
            switch self {
            case let .address(address):
                address
            case let .temporary(address):
                address
            case let .commonWallet(_, address):
                address
            }
        }
        
        var destination: String {
            withdrawable.destination
        }
        
        var reportingType: String {
            switch self {
            case .address:
                "address_book"
            case .temporary:
                "address"
            case .commonWallet:
                "wallet"
            }
        }
        
        var debugDescription: String {
            switch self {
            case let .address(address):
                return "<WithdrawalDestination.address \(address.addressId)>"
            case let .temporary(address):
                return "<WithdrawalDestination.temporary \(address.destination)>"
            case let .commonWallet(wallet, _):
                return "<WithdrawalDestination.commonWallet \(wallet.name)>"
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
                    NoPendingTransactionPrecondition(),
                    AddressDustPrecondition(token: token,
                                            amount: tokenAmount,
                                            address: address),
                    DuplicationPrecondition(operation: .withdraw(address),
                                            token: token,
                                            tokenAmount: tokenAmount,
                                            fiatMoneyAmount: fiatMoneyAmount,
                                            memo: memo),
                    InactiveAddressPrecondition(address: address),
                ]
            case .temporary, .commonWallet:
                preconditions = [
                    NoPendingTransactionPrecondition(),
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
                let result = await collectOutputs(token: token, amount: amount, on: parent)
                switch result {
                case .success(let collection):
                    let addressLabel: AddressLabel?
                    let addressID: String?
                    switch destination {
                    case let .address(address):
                        addressLabel = .addressBook(address.label)
                        addressID = address.addressId
                    case .temporary:
                        addressLabel = nil
                        addressID = nil
                    case let .commonWallet(wallet, _):
                        addressLabel = .wallet(.common(wallet))
                        addressID = nil
                    }
                    let operation = WithdrawPaymentOperation(
                        traceID: traceID,
                        withdrawalToken: token,
                        withdrawalTokenAmount: tokenAmount,
                        withdrawalFiatMoneyAmount: fiatMoneyAmount,
                        withdrawalOutputs: collection,
                        feeToken: fee.tokenItem,
                        feeAmount: fee.amount,
                        address: destination.withdrawable,
                        addressLabel: addressLabel,
                        addressID: addressID
                    )
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
