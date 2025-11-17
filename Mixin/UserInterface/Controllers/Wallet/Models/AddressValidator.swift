import Foundation
import MixinServices

enum AddressValidator {
    
    enum WithdrawalValidationResult {
        case tagNeeded(AddressInfoInputViewController)
        case addressVerified(MixinTokenItem, Payment.WithdrawalDestination)
        case insufficientBalance(withdrawing: BalanceRequirement, fee: BalanceRequirement)
        case withdrawPayment(Payment, Payment.WithdrawalDestination, WithdrawFeeItem)
    }
    
    enum ValidationError: Error, LocalizedError {
        
        case unknownAssetKey
        case invalidFormat
        case amountTooSmall
        case mismatchedDestination
        case mismatchedTag
        
        var errorDescription: String? {
            switch self {
            case .unknownAssetKey:
                R.string.localizable.insufficient_balance()
            case .invalidFormat, .amountTooSmall:
                R.string.localizable.invalid_payment_link()
            case .mismatchedDestination, .mismatchedTag:
                R.string.localizable.invalid_address()
            }
        }
        
    }
    
    static func validate(
        string: String,
        withdrawing withdrawingToken: MixinTokenItem?,
        onSuccess: @escaping @MainActor (WithdrawalValidationResult) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let link: ExternalTransfer
                if ExternalTransfer.isLightningAddress(string: string) {
                    let payment = try await PaymentAPI.payments(lightningPayment: string)
                    link = try ExternalTransfer(payment: payment)
                } else {
                    link = try ExternalTransfer(string: string)
                }
                
                let linkToken: MixinTokenItem
                switch link.tokenID {
                case .assetID(let id):
                    linkToken = try await syncToken(assetID: id)
                case .assetKey(let key):
                    if let localToken = TokenDAO.shared.tokenItem(chainID: link.chainID, assetKey: key) {
                        linkToken = localToken
                    } else {
                        throw ValidationError.unknownAssetKey
                    }
                }
                
                let amount = try await link.decimalAmount(precision: {
                    // Since the amount is decoded from the link, it should be calculated using the token specified in the link.
                    try await AssetAPI.assetPrecision(assetID: linkToken.assetID).precision
                })
                if let amount, amount > 0 {
                    if amount < MixinToken.minimalAmount {
                        throw ValidationError.amountTooSmall
                    }
                    if let withdrawingToken, withdrawingToken.assetID != linkToken.assetID {
                        throw ValidationError.invalidFormat
                    }
                    // From now on, withdrawingToken is same as linkToken
                    let token = linkToken
                    let destination = try await validate(
                        chainID: token.chainID,
                        assetID: token.assetID,
                        destination: link.destination,
                        tag: nil
                    )
                    let balanceSufficiency = try await checkBalanceSufficiency(
                        withdrawingToken: token,
                        amount: amount,
                        destination: destination.withdrawable.destination
                    )
                    switch balanceSufficiency {
                    case let .insufficient(withdrawing, fee):
                        await MainActor.run {
                            onSuccess(.insufficientBalance(withdrawing: withdrawing, fee: fee))
                        }
                    case let .sufficient(feeItem):
                        let fiatMoneyAmount = amount * token.decimalUSDPrice * Decimal(Currency.current.rate)
                        let payment = Payment(
                            traceID: UUID().uuidString.lowercased(),
                            token: token,
                            tokenAmount: amount,
                            fiatMoneyAmount: fiatMoneyAmount,
                            memo: link.memo ?? ""
                        )
                        await MainActor.run {
                            onSuccess(.withdrawPayment(payment, destination, feeItem))
                        }
                    }
                } else {
                    if let withdrawingToken, withdrawingToken.chainID != linkToken.chainID {
                        throw ValidationError.invalidFormat
                    }
                    let token = withdrawingToken ?? linkToken
                    let destination = try await validate(
                        chainID: token.chainID,
                        assetID: token.assetID,
                        destination: link.destination,
                        tag: nil
                    )
                    await MainActor.run {
                        onSuccess(.addressVerified(token, destination))
                    }
                }
            } catch TransferLinkError.notTransferLink {
                await MainActor.run {
                    guard let token = withdrawingToken else {
                        onFailure(TransferLinkError.notTransferLink)
                        return
                    }
                    let tagInput: AddressInfoInputViewController? = .oneTimeWithdraw(
                        token: token,
                        destination: string
                    )
                    if let tagInput {
                        validateSkippingTag(
                            chainID: token.chainID,
                            assetID: token.assetID,
                            destination: string
                        ) {
                            onSuccess(.tagNeeded(tagInput))
                        } onFailure: { error in
                            onFailure(error)
                        }
                    } else {
                        validate(
                            chainID: token.chainID,
                            assetID: token.assetID,
                            destination: string,
                            tag: nil
                        ) { destination in
                            onSuccess(.addressVerified(token, destination))
                        } onFailure: { error in
                            onFailure(error)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    static func validate(
        chainID: String,
        assetID: String,
        destination: String,
        tag: String?,
        onSuccess: @escaping @MainActor (Payment.WithdrawalDestination) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let destination = try await validate(
                    chainID: chainID,
                    assetID: assetID,
                    destination: destination,
                    tag: tag
                )
                await MainActor.run {
                    onSuccess(destination)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    static func validateSkippingTag(
        chainID: String,
        assetID: String,
        destination: String,
        onSuccess: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let response = try await ExternalAPI.checkAddressSkippingTag(
                    chainID: chainID,
                    assetID: assetID,
                    destination: destination
                )
                guard destination.lowercased() == response.destination.lowercased() else {
                    throw ValidationError.mismatchedDestination
                }
                await MainActor.run {
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
}

extension AddressValidator {
    
    private enum BalanceSufficiency {
        case sufficient(WithdrawFeeItem)
        case insufficient(withdrawing: BalanceRequirement, fee: BalanceRequirement)
    }
    
    private static func checkBalanceSufficiency(
        withdrawingToken: MixinTokenItem,
        amount: Decimal,
        destination: String,
    ) async throws -> BalanceSufficiency {
        let fees = try await SafeAPI.fees(
            assetID: withdrawingToken.assetID,
            destination: destination
        )
        
        var feeItems: [WithdrawFeeItem] = []
        for fee in fees {
            let feeToken = try await syncToken(assetID: fee.assetID)
            let feeItem = WithdrawFeeItem(amountString: fee.amount, tokenItem: feeToken)
            if let feeItem {
                feeItems.append(feeItem)
            } else {
                Logger.general.error(
                    category: "AddressValidator",
                    message: "Invalid fee amount: \(fee.amount), fee token: \(feeToken.assetID)"
                )
                throw MixinAPIResponseError.internalServerError
            }
        }
        guard let firstFeeItem = feeItems.first else {
            throw MixinAPIResponseError.withdrawSuspended
        }
        
        let withdrawRequirement = BalanceRequirement(
            token: withdrawingToken,
            amount: amount
        )
        let sufficientFeeItems = feeItems.lazy.compactMap { item in
            let feeRequirement = BalanceRequirement(
                token: item.tokenItem,
                amount: item.amount
            )
            let requirements = feeRequirement.merging(with: withdrawRequirement)
            if requirements.allSatisfy(\.isSufficient) {
                return item
            } else {
                return nil
            }
        }
        if let feeItem = sufficientFeeItems.first {
            return .sufficient(feeItem)
        } else {
            let feeRequirement = BalanceRequirement(
                token: firstFeeItem.tokenItem,
                amount: firstFeeItem.amount
            )
            return .insufficient(withdrawing: withdrawRequirement, fee: feeRequirement)
        }
    }
    
}

extension AddressValidator {
    
    private static func validate(
        chainID: String,
        assetID: String,
        destination: String,
        tag: String?,
    ) async throws -> Payment.WithdrawalDestination {
        if let wallet = Web3WalletDAO.shared.wallet(destination: destination),
           let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chainID)
        {
            return .commonWallet(wallet, address)
        } else if let address = AddressDAO.shared.getAddress(chainId: chainID, destination: destination, tag: tag ?? "") {
            return .address(address)
        } else  {
            let response = try await ExternalAPI.checkAddress(
                chainID: chainID,
                assetID: assetID,
                destination: destination,
                tag: tag
            )
            guard destination.lowercased() == response.destination.lowercased() else {
                throw ValidationError.mismatchedDestination
            }
            guard (tag.isNilOrEmpty && response.tag.isNilOrEmpty) || tag == response.tag else {
                throw ValidationError.mismatchedTag
            }
            let address = TemporaryAddress(destination: destination, tag: tag ?? "")
            return .temporary(address)
        }
    }
    
    private static func syncToken(assetID: String) async throws -> MixinTokenItem {
        let token: MixinTokenItem
        if let localToken = TokenDAO.shared.tokenItem(assetID: assetID) {
            token = localToken
        } else {
            let remoteToken = try await SafeAPI.assets(id: assetID)
            TokenDAO.shared.save(token: remoteToken)
            token = MixinTokenItem(token: remoteToken, balance: "0", isHidden: false, chain: nil)
        }
        if token.chain == nil {
            let chain: Chain
            if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                chain = localChain
            } else {
                let remoteChain = try await NetworkAPI.chain(id: token.chainID)
                ChainDAO.shared.save([remoteChain])
                Web3ChainDAO.shared.save([remoteChain])
                chain = remoteChain
            }
            return MixinTokenItem(token: token, balance: token.balance, isHidden: token.isHidden, chain: chain)
        } else {
            return token
        }
    }
    
}
