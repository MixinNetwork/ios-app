import Foundation
import MixinServices

struct Payment {
    
    let traceID: String
    let token: TokenItem
    let tokenAmount: Decimal
    let fiatMoneyAmount: Decimal
    let memo: String
    
    private let inscriptionContext: InscriptionContext?
    
    init(traceID: String, token: TokenItem, tokenAmount: Decimal, fiatMoneyAmount: Decimal, memo: String) {
        self.traceID = traceID
        self.token = token
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.memo = memo
        self.inscriptionContext = nil
    }
    
    init?(traceID: String, output: Output, item: InscriptionItem) {
        guard
            let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset),
            let amount = Decimal(string: output.amount, locale: .enUSPOSIX)
        else {
            return nil
        }
        
        self.init(traceID: traceID, amount: amount, token: token, output: output, item: item)
    }
    
    init(traceID: String, amount: Decimal, token: TokenItem, output: Output, item: InscriptionItem) {
        let fiatMoneyAmount = amount * token.decimalUSDPrice * Currency.current.decimalRate
        self.traceID = traceID
        self.token = token
        self.tokenAmount = amount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.memo = ""
        self.inscriptionContext = InscriptionContext(output: output, item: item)
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
    
    private struct InscriptionContext {
        let output: Output
        let item: InscriptionItem
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
                if inscriptionContext == nil {
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
                        OpponentIsContactPrecondition(opponent: opponent),
                        ReferenceValidityPrecondition(reference: reference),
                    ]
                } else {
                    preconditions = [
                        NoPendingTransactionPrecondition(token: token),
                        AlreadyPaidPrecondition(traceID: traceID),
                        OpponentIsContactPrecondition(opponent: opponent),
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
                let item: InscriptionItem?
                let outputCollectionResult: OutputCollectingResult
                if let inscriptionContext {
                    item = inscriptionContext.item
                    if let collection = UTXOService.OutputCollection(output: inscriptionContext.output) {
                        outputCollectionResult = .success(collection)
                    } else {
                        outputCollectionResult = .failure(.description("Invalid Amount"))
                    }
                } else {
                    item = nil
                    outputCollectionResult = await collectOutputs(kernelAssetID: token.kernelAssetID, amount: tokenAmount, on: parent)
                }
                
                switch outputCollectionResult {
                case .success(let collection):
                    let operation = TransferPaymentOperation(traceID: traceID,
                                                             spendingOutputs: collection,
                                                             destination: destination,
                                                             token: token,
                                                             amount: tokenAmount,
                                                             memo: memo,
                                                             reference: reference,
                                                             inscription: item)
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
