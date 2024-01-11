import Foundation
import MixinServices

enum PaymentPreconditionFailureReason {
    case userCancelled
    case description(String)
}

enum PaymentPreconditionCheckingResult {
    case passed
    case failed(PaymentPreconditionFailureReason)
}

protocol PaymentPrecondition {
    func check() async -> PaymentPreconditionCheckingResult
}

struct AddressDustPrecondition: PaymentPrecondition {
    
    let token: TokenItem
    let amount: Decimal
    let address: Address
    
    func check() async -> PaymentPreconditionCheckingResult {
        if amount < address.decimalDust {
            let dust = CurrencyFormatter.localizedString(from: address.decimalDust, format: .precision, sign: .never)
            return .failed(.description(R.string.localizable.withdrawal_minimum_amount(dust, token.symbol)))
        } else {
            return .passed
        }
    }
    
}

struct AlreadyPaidPrecondition: PaymentPrecondition {
    
    let traceID: String
    
    func check() async -> PaymentPreconditionCheckingResult {
        do {
            let _ = try await SafeAPI.transaction(id: traceID)
            return .failed(.description(R.string.localizable.pay_paid()))
        } catch MixinAPIError.notFound {
            return .passed
        } catch {
            return .failed(.description(error.localizedDescription))
        }
    }
    
}

struct DuplicationPrecondition: PaymentPrecondition {
    
    enum Operation {
        case transfer(UserItem)
        case withdraw(WithdrawableAddress)
    }
    
    let operation: Operation
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    
    func check() async -> PaymentPreconditionCheckingResult {
        guard AppGroupUserDefaults.User.duplicateTransferConfirmation else {
            return .passed
        }
        
        let trace: Trace?
        let createdAt = Date().addingTimeInterval(-6 * .hour).toUTCString()
        let operation: DuplicateConfirmationWindow.Operation
        switch self.operation {
        case .transfer(let opponent):
            trace = TraceDAO.shared.getTrace(assetId: token.assetID,
                                             amount: Token.amountString(from: tokenAmount),
                                             opponentId: opponent.userId,
                                             destination: nil,
                                             tag: nil,
                                             createdAt: createdAt)
            operation = .transfer(opponent)
        case let .withdraw(address):
            trace = TraceDAO.shared.getTrace(assetId: token.assetID,
                                             amount: Token.amountString(from: tokenAmount),
                                             opponentId: nil,
                                             destination: address.destination,
                                             tag: address.tag,
                                             createdAt: createdAt)
            operation = .withdraw(address)
        }
        guard let trace else {
            return .passed
        }
        
        let traceCreatedAt: Date
        if let id = trace.snapshotId, !id.isEmpty {
            traceCreatedAt = trace.createdAt.toUTCDate()
        } else {
            do {
                let response = try await SafeAPI.transaction(id: trace.traceId)
                TraceDAO.shared.updateSnapshot(traceId: trace.traceId, snapshotId: response.snapshotID)
                traceCreatedAt = response.createdAt.toUTCDate()
            } catch MixinAPIError.notFound {
                return .passed
            } catch {
                return .failed(.description(error.localizedDescription))
            }
        }
        
        let isConfirmed = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DuplicateConfirmationWindow.instance()
                    .render(token: token, operation: operation, amount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, traceCreatedAt: traceCreatedAt, completion: { isConfirmed, _ in
                        continuation.resume(with: .success(isConfirmed))
                    })
                    .presentPopupControllerAnimated()
            }
        }
        if isConfirmed {
            return .passed
        } else {
            return .failed(.userCancelled)
        }
    }
    
}

struct TransferAmountPrecondition: PaymentPrecondition {
    
    let opponent: UserItem
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    
    func check() async -> PaymentPreconditionCheckingResult {
        let threshold = Decimal(LoginManager.shared.account?.transferConfirmationThreshold ?? 0)
        if threshold != 0 && fiatMoneyAmount >= threshold {
            let isConfirmed = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    BigAmountConfirmationWindow.instance()
                        .render(token: token, to: opponent, amount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: { isConfirmed, _ in
                            continuation.resume(with: .success(isConfirmed))
                        })
                        .presentPopupControllerAnimated()
                }
            }
            if isConfirmed {
                return .passed
            } else {
                return .failed(.userCancelled)
            }
        } else {
            return .passed
        }
    }
    
}

struct FirstWithdrawPrecondition: PaymentPrecondition {
    
    let addressID: String
    let token: TokenItem
    let fiatMoneyAmount: Decimal
    
    func check() async -> PaymentPreconditionCheckingResult {
        guard AppGroupUserDefaults.Wallet.withdrawnAddressIds[addressID] == nil && fiatMoneyAmount > 10 else {
            return .passed
        }
        let isConfirmed = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                WithdrawalTipWindow.instance()
                    .render(token: token, completion: { isConfirmed, _ in
                        continuation.resume(with: .success(isConfirmed))
                    })
                    .presentPopupControllerAnimated()
            }
        }
        if isConfirmed {
            return .passed
        } else {
            return .failed(.userCancelled)
        }
    }
    
}

struct NoPendingTransactionPrecondition: PaymentPrecondition {
    
    let token: TokenItem
    
    func check() async -> PaymentPreconditionCheckingResult {
        let count = RawTransactionDAO.shared.unspentRawTransactionCount(types: [.transfer, .withdrawal])
        if count > 0 {
            let delegation = UserRealizedDelegation()
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    delegation.completion = {
                        continuation.resume(with: .success(.failed(.userCancelled)))
                    }
                    let hint = WalletHintViewController(token: token)
                    hint.setTitle(R.string.localizable.waiting_transaction(),
                                  description: R.string.localizable.waiting_transaction_description())
                    hint.contactSupportButton.alpha = 0
                    hint.delegate = delegation
                    UIApplication.homeContainerViewController?.present(hint, animated: true)
                    ConcurrentJobQueue.shared.addJob(job: RecoverRawTransactionJob())
                }
            }
        } else {
            return .passed
        }
    }
    
    private class UserRealizedDelegation: WalletHintViewControllerDelegate {
        
        var completion: (() -> Void)?
        
        func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
            completion?()
        }
        
        func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
            
        }
        
    }
    
}
