import Foundation
import MixinServices

struct Payment {
    
    let traceID: String
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    
}

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
    
    func checkPreconditions(
        transferTo destination: TransferDestination,
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (TransferPaymentOperation) -> Void
    ) {
        Task {
            let preconditions: [PaymentPrecondition]
            switch destination {
            case let .user(opponent):
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    DuplicationPrecondition(operation: .transfer(opponent),
                                            token: token,
                                            tokenAmount: tokenAmount,
                                            fiatMoneyAmount: fiatMoneyAmount,
                                            memo: memo),
                    TransferAmountPrecondition(opponent: opponent,
                                               token: token,
                                               tokenAmount: tokenAmount,
                                               fiatMoneyAmount: fiatMoneyAmount,
                                               memo: memo)
                ]
            case .multisig, .mainnet:
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    AlreadyPaidPrecondition(traceID: traceID)
                ]
            }
            switch await check(preconditions: preconditions) {
            case .passed:
                break
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
                return
            }
            
            let result = await collectOutputs(kernelAssetID: token.kernelAssetID, amount: tokenAmount, on: parent)
            switch result {
            case .success(let collection):
                let operation = TransferPaymentOperation(traceID: traceID,
                                                         spendingOutputs: collection,
                                                         destination: destination,
                                                         token: token,
                                                         tokenAmount: tokenAmount,
                                                         memo: memo)
                await MainActor.run {
                    onSuccess(operation)
                }
            case .failure(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            }
        }
    }
    
}

extension Payment {
    
    enum WithdrawalDestination {
        
        case address(Address)
        case temporary(TemporaryAddress)
        
        var withdrawable: WithdrawableAddress {
            switch self {
            case .address(let address):
                return address
            case .temporary(let address):
                return address
            }
        }
        
        var debugDescription: String {
            switch self {
            case let .address(address):
                return "<WithdrawalDestination.address \(address.addressId)>"
            case let .temporary(address):
                return "<WithdrawalDestination.temporary \(address.destination)>"
            }
        }
        
    }
    
    func checkPreconditions(
        withdrawTo destination: WithdrawalDestination,
        fee: WithdrawFeeItem,
        on parent: UIViewController,
        onFailure: @MainActor @escaping (PaymentPreconditionFailureReason) -> Void,
        onSuccess: @MainActor @escaping (WithdrawPaymentOperation) -> Void
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
                    FirstWithdrawPrecondition(addressID: address.addressId,
                                              token: token,
                                              fiatMoneyAmount: fiatMoneyAmount)
                ]
            case let .temporary(address):
                preconditions = [
                    NoPendingTransactionPrecondition(token: token),
                    DuplicationPrecondition(operation: .withdraw(address),
                                            token: token,
                                            tokenAmount: tokenAmount,
                                            fiatMoneyAmount: fiatMoneyAmount,
                                            memo: memo)
                ]
            }
            
            switch await check(preconditions: preconditions) {
            case .passed:
                break
            case .failed(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
                return
            }
            
            let amount: Decimal
            if fee.tokenItem.assetID == token.assetID {
                amount = tokenAmount + fee.amount
            } else {
                amount = tokenAmount
            }
            let result = await collectOutputs(kernelAssetID: token.kernelAssetID, amount: amount, on: parent)
            switch result {
            case .success(let collection):
                let addressID: String?
                switch destination {
                case let .address(address):
                    addressID = address.addressId
                case .temporary:
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
                                                         addressID: addressID)
                await MainActor.run {
                    onSuccess(operation)
                }
            case .failure(let reason):
                await MainActor.run {
                    onFailure(reason)
                }
            }
        }
    }
    
}

extension Payment {
    
    enum OutputCollectingResult {
        case success(UTXOService.OutputCollection)
        case failure(PaymentPreconditionFailureReason)
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
        for precondition in preconditions {
            let result = await precondition.check()
            switch result {
            case .passed:
                continue
            case .failed(let reason):
                return .failed(reason)
            }
        }
        return .passed
    }
    
}
