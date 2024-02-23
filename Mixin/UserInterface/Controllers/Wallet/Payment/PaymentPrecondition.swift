import Foundation
import MixinServices

enum PaymentPreconditionFailureReason {
    case userCancelled
    case description(String)
}

enum PaymentPreconditionIssue {
    
    case duplication(previous: Date, amount: Decimal, symbol: String)
    case bigAmount(opponent: UserItem, value: Decimal, symbol: String)
    case notContact(opponent: UserItem)
    case agedAddress(label: String, compactRepresentation: String)
    
    var description: String {
        switch self {
        case let .duplication(previous, amount, symbol):
            let amount = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .never, symbol: .custom(symbol))
            let interval = previous.simpleTimeAgo()
            return R.string.localizable.duplication_reminder(amount, interval)
        case let .bigAmount(user, value, symbol):
            let value = CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
            return R.string.localizable.large_amount_reminder(value, symbol, user.fullName, user.identityNumber)
        case let .notContact(user):
            return R.string.localizable.unfamiliar_person_reminder(user.fullName, user.identityNumber)
        case let .agedAddress(label, compactRepresentation):
            return R.string.localizable.address_validity_reminder(label, compactRepresentation)
        }
    }
    
}

enum PaymentPreconditionCheckingResult {
    case passed([PaymentPreconditionIssue])
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
            return .passed([])
        }
    }
    
}

struct AlreadyPaidPrecondition: PaymentPrecondition {
    
    let traceID: String
    
    func check() async -> PaymentPreconditionCheckingResult {
        do {
            let _ = try await SafeAPI.transaction(id: traceID)
            return .failed(.description(R.string.localizable.pay_paid()))
        } catch MixinAPIResponseError.notFound {
            return .passed([])
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
            return .passed([])
        }
        
        let createdAt = Date().addingTimeInterval(-6 * .hour).toUTCString()
        let trace: Trace? = switch self.operation {
        case .transfer(let opponent):
            TraceDAO.shared.getTrace(assetId: token.assetID,
                                             amount: Token.amountString(from: tokenAmount),
                                             opponentId: opponent.userId,
                                             destination: nil,
                                             tag: nil,
                                             createdAt: createdAt)
        case let .withdraw(address):
            TraceDAO.shared.getTrace(assetId: token.assetID,
                                             amount: Token.amountString(from: tokenAmount),
                                             opponentId: nil,
                                             destination: address.destination,
                                             tag: address.tag,
                                             createdAt: createdAt)
        }
        guard let trace else {
            return .passed([])
        }
        
        let traceCreatedAt: Date
        if let id = trace.snapshotId, !id.isEmpty {
            traceCreatedAt = trace.createdAt.toUTCDate()
        } else {
            do {
                let response = try await SafeAPI.transaction(id: trace.traceId)
                TraceDAO.shared.updateSnapshot(traceId: trace.traceId, snapshotId: response.snapshotID)
                traceCreatedAt = response.createdAt.toUTCDate()
            } catch MixinAPIResponseError.notFound {
                return .passed([])
            } catch {
                return .failed(.description(error.localizedDescription))
            }
        }
        
        return .passed([.duplication(previous: traceCreatedAt, amount: tokenAmount, symbol: token.symbol)])
    }
    
}

struct LargeAmountPrecondition: PaymentPrecondition {
    
    let opponent: UserItem
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    
    func check() async -> PaymentPreconditionCheckingResult {
        let threshold = Decimal(LoginManager.shared.account?.transferConfirmationThreshold ?? 0)
        if threshold != 0 && fiatMoneyAmount >= threshold {
            return .passed([.bigAmount(opponent: opponent, value: fiatMoneyAmount, symbol: token.symbol)])
        } else {
            return .passed([])
        }
    }
    
}

struct OpponentIsContactPrecondition: PaymentPrecondition {
    
    let opponent: UserItem
    
    func check() async -> PaymentPreconditionCheckingResult {
        if UserDAO.shared.isUserFriend(id: opponent.userId) {
            return .passed([])
        } else {
            return .passed([.notContact(opponent: opponent)])
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
            return .passed([])
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

struct AddressValidityPrecondition: PaymentPrecondition {
    
    let address: Address
    
    func check() async -> PaymentPreconditionCheckingResult {
        if let createdAt = RawTransactionDAO.shared.latestCreatedAt(receiverID: address.fullRepresentation) {
            let date = createdAt.toUTCDate()
            if -date.timeIntervalSinceNow > 30 * .day {
                return .passed([.agedAddress(label: address.label, compactRepresentation: address.compactRepresentation)])
            } else {
                return .passed([])
            }
        } else {
            return .passed([])
        }
    }
    
}
