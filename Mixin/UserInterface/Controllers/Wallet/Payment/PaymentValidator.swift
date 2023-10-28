import UIKit
import MixinServices

final class PaymentValidator {
    
    enum Result {
        case passed
        case userCancelled
        case failure(String)
    }
    
    enum Operation {
        case transfer(UserItem)
        case withdraw(Address)
    }
    
    let traceID: String
    let token: TokenItem
    let memo: String
    
    init(traceID: String, token: TokenItem, memo: String) {
        self.traceID = traceID
        self.token = token
        self.memo = memo
    }
    
    func transfer(
        to opponent: UserItem,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        completion: @escaping (Result) -> Void
    ) {
        if AppGroupUserDefaults.User.duplicateTransferConfirmation {
            detectDuplication(token: token, tokenAmount: amount, fiatMoneyAmount: fiatMoneyAmount, operation: .transfer(opponent)) { result in
                assert(Queue.main.isCurrent)
                switch result {
                case .passed:
                    self.validateAmount(operation: .transfer(opponent), amount: amount, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
                case .userCancelled, .failure:
                    completion(result)
                }
            }
        } else {
            validateAmount(operation: .transfer(opponent), amount: amount, fiatMoneyAmount: fiatMoneyAmount, completion: completion)
        }
    }
    
    private func validateAmount(
        operation: Operation,
        amount: Decimal,
        fiatMoneyAmount: Decimal,
        completion: @escaping (Result) -> Void
    ) {
        switch operation {
        case let .transfer(opponent):
            let threshold = Decimal(LoginManager.shared.account?.transferConfirmationThreshold ?? 0)
            if threshold != 0 && fiatMoneyAmount >= threshold {
                DispatchQueue.main.async { [token, memo] in
                    BigAmountConfirmationWindow.instance()
                        .render(token: token, to: opponent, amount: amount, fiatMoneyAmount: fiatMoneyAmount, memo: memo, completion: { isConfirmed, _ in
                            if isConfirmed {
                                completion(.passed)
                            } else {
                                completion(.userCancelled)
                            }
                        })
                        .presentPopupControllerAnimated()
                }
            } else {
                completion(.passed)
            }
        case let .withdraw(address):
            if let dust = Decimal(string: address.dust, locale: .enUSPOSIX), amount < dust {
                completion(.failure(R.string.localizable.withdrawal_minimum_amount(address.dust, token.symbol)))
            } else if AppGroupUserDefaults.Wallet.withdrawnAddressIds[address.addressId] == nil && fiatMoneyAmount > 10 {
                WithdrawalTipWindow.instance()
                    .render(token: token, completion: { isConfirmed, _ in
                        if isConfirmed {
                            completion(.passed)
                        } else {
                            completion(.userCancelled)
                        }
                    })
                    .presentPopupControllerAnimated()
            } else {
                completion(.passed)
            }
        }
    }
    
    private func detectDuplication(
        token: TokenItem,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        operation: Operation,
        completion: @escaping (Result) -> Void
    ) {
        DispatchQueue.global().async { [token, traceID] in
            let trace: Trace?
            let createdAt = Date().addingTimeInterval(-6 * .hour).toUTCString()
            switch operation {
            case let .transfer(opponent):
                trace = TraceDAO.shared.getTrace(assetId: token.assetID,
                                                 amount: Token.amountString(from: tokenAmount),
                                                 opponentId: opponent.userId,
                                                 destination: nil,
                                                 tag: nil,
                                                 createdAt: createdAt)
            case let .withdraw(address):
                trace = TraceDAO.shared.getTrace(assetId: token.assetID,
                                                 amount: Token.amountString(from: tokenAmount),
                                                 opponentId: nil,
                                                 destination: address.destination,
                                                 tag: address.tag,
                                                 createdAt: createdAt)
            }
            guard let trace else {
                DispatchQueue.main.async {
                    completion(.passed)
                }
                return
            }
            
            let traceCreatedAt: Date
            if let id = trace.snapshotId, !id.isEmpty {
                traceCreatedAt = trace.createdAt.toUTCDate()
            } else {
                switch SnapshotAPI.trace(traceId: traceID) {
                case let .success(snapshot):
                    TraceDAO.shared.updateSnapshot(traceId: traceID, snapshotId: snapshot.snapshotId)
                    traceCreatedAt = snapshot.createdAt.toUTCDate()
                case .failure(.notFound):
                    DispatchQueue.main.async {
                        completion(.passed)
                    }
                    return
                case let .failure(error):
                    DispatchQueue.main.async {
                        completion(.failure(error.localizedDescription))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                DuplicateConfirmationWindow.instance()
                    .render(token: token, operation: operation, amount: tokenAmount, fiatMoneyAmount: fiatMoneyAmount, memo: self.memo, traceCreatedAt: traceCreatedAt, completion: { isConfirmed, _ in
                        if isConfirmed {
                            completion(.passed)
                        } else {
                            completion(.userCancelled)
                        }
                    })
                    .presentPopupControllerAnimated()
            }
        }
    }
    
}
