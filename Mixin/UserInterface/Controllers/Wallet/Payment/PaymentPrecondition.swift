import Foundation
import MixinServices

enum PaymentPreconditionFailureReason {
    case userCancelled
    case loggedOut
    case description(String)
}

enum OutputCollectingResult {
    case success(UTXOService.OutputCollection)
    case failure(PaymentPreconditionFailureReason)
}

enum PaymentPreconditionIssue {
    
    case duplication(previous: Date, amount: Decimal, symbol: String)
    case bigAmount(tokenAmount: Decimal, fiatMoneyAmount: Decimal, symbol: String)
    case notContact(opponent: UserItem)
    case agedAddress(label: String, compactRepresentation: String, age: Int)
    
    var description: String {
        switch self {
        case let .duplication(previous, amount, symbol):
            let amount = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .never, symbol: .custom(symbol))
            let interval = previous.simpleTimeAgo()
            return R.string.localizable.duplication_reminder(amount, interval)
        case let .bigAmount(tokenAmount, fiatMoneyAmount, symbol):
            let tokenValue = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(symbol))
            let fiatMoneyValue = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            return R.string.localizable.large_amount_reminder(tokenValue, fiatMoneyValue)
        case let .notContact(user):
            return R.string.localizable.unfamiliar_person_reminder(user.fullName, user.identityNumber)
        case let .agedAddress(label, compactRepresentation, age):
            return R.string.localizable.address_validity_reminder(label, compactRepresentation, "\(age)")
        }
    }
    
}

enum PaymentPreconditionCheckingResult {
    case passed([PaymentPreconditionIssue])
    case failed(PaymentPreconditionFailureReason)
}

protocol PaymentPreconditionChecker {
    func check(preconditions: [PaymentPrecondition]) async -> PaymentPreconditionCheckingResult
}

extension PaymentPreconditionChecker {
    
    func check(preconditions: [PaymentPrecondition]) async -> PaymentPreconditionCheckingResult {
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
    
    func collectOutputs(
        token: MixinTokenItem,
        amount: Decimal,
        on parent: UIViewController
    ) async -> OutputCollectingResult {
        repeat {
            let result = UTXOService.shared.collectAvailableOutputs(
                kernelAssetID: token.kernelAssetID,
                amount: amount
            )
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
        } while LoginManager.shared.isLoggedIn
        return .failure(.loggedOut)
    }
    
}

protocol PaymentPrecondition {
    func check() async -> PaymentPreconditionCheckingResult
}

struct AddressDustPrecondition: PaymentPrecondition {
    
    let token: MixinTokenItem
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
    
    let traceIDs: [String]
    
    init(traceID: String) {
        self.traceIDs = []
    }
    
    init(traceIDs: [String]) {
        self.traceIDs = traceIDs
    }
    
    func check() async -> PaymentPreconditionCheckingResult {
        do {
            let transactions = try await SafeAPI.transactions(ids: traceIDs)
            return if transactions.isEmpty {
                .passed([])
            } else {
                .failed(.description(R.string.localizable.pay_paid()))
            }
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
    let token: MixinTokenItem
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
                                     amount: TokenAmountFormatter.string(from: tokenAmount),
                                     opponentId: opponent.userId,
                                     destination: nil,
                                     tag: nil,
                                     createdAt: createdAt)
        case let .withdraw(address):
            TraceDAO.shared.getTrace(assetId: token.assetID,
                                             amount: TokenAmountFormatter.string(from: tokenAmount),
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
    
    let token: MixinTokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    
    func check() async -> PaymentPreconditionCheckingResult {
        let threshold = Decimal(LoginManager.shared.account?.transferConfirmationThreshold ?? 0)
        if threshold != 0 && fiatMoneyAmount >= threshold {
            return .passed([.bigAmount(tokenAmount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount, symbol: token.symbol)])
        } else {
            return .passed([])
        }
    }
    
}

struct KnownOpponentPrecondition: PaymentPrecondition {
    
    let opponent: UserItem
    
    func check() async -> PaymentPreconditionCheckingResult {
        if UserDAO.shared.isUserFriendOrMe(id: opponent.userId) {
            return .passed([])
        } else {
            return .passed([.notContact(opponent: opponent)])
        }
    }
    
}

struct NoPendingTransactionPrecondition: PaymentPrecondition {
    
    func check() async -> PaymentPreconditionCheckingResult {
        let count = RawTransactionDAO.shared.unspentRawTransactionCount(types: [.transfer, .withdrawal])
        if count > 0 {
            let delegation = WalletHintViewController.UserRealizedDelegation()
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    delegation.onRealize = {
                        continuation.resume(with: .success(.failed(.userCancelled)))
                    }
                    let hint = WalletHintViewController(content: .waitingTransaction)
                    hint.delegate = delegation
                    UIApplication.homeContainerViewController?.present(hint, animated: true)
                    ConcurrentJobQueue.shared.addJob(job: RecoverRawTransactionJob())
                }
            }
        } else {
            return .passed([])
        }
    }
    
}

struct AddressValidityPrecondition: PaymentPrecondition {
    
    let address: Address
    let maxNumberOfDays = 30
    
    func check() async -> PaymentPreconditionCheckingResult {
        if let createdAt = RawTransactionDAO.shared.latestCreatedAt(receiverID: address.fullRepresentation) {
            let date = createdAt.toUTCDate()
            if -date.timeIntervalSinceNow > TimeInterval(maxNumberOfDays) * .day {
                return .passed([.agedAddress(label: address.label, compactRepresentation: address.compactRepresentation, age: maxNumberOfDays)])
            } else {
                return .passed([])
            }
        } else {
            return .passed([])
        }
    }
    
}

struct ReferenceValidityPrecondition: PaymentPrecondition {
    
    let reference: String?
    
    func check() async -> PaymentPreconditionCheckingResult {
        if let reference {
            if let data = Data(hexEncodedString: reference), data.count == 32 {
                return .passed([])
            } else {
                return .failed(.description(R.string.localizable.invalid_payment_link()))
            }
        } else {
            return .passed([])
        }
    }
    
}
