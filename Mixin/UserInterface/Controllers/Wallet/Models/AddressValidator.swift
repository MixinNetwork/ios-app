import Foundation
import MixinServices

enum AddressValidator {
    
    enum ValidationError: Error, LocalizedError {
        
        case invalidFormat
        case mismatchedDestination
        case mismatchedTag
        case insufficientFee(WithdrawFeeItem?)
        case insufficientBalance(MixinTokenItem)
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                R.string.localizable.invalid_payment_link()
            case .mismatchedDestination, .mismatchedTag:
                R.string.localizable.invalid_address()
            case .insufficientFee(let fee):
                if let fee {
                    R.string.localizable.insufficient_fee_description(
                        fee.localizedAmountWithSymbol,
                        fee.tokenItem.chain?.name ?? ""
                    )
                } else {
                    R.string.localizable.insufficient_transaction_fee()
                }
            case .insufficientBalance:
                R.string.localizable.insufficient_balance()
            }
        }
        
    }
    
    static func validateWithdrawalLink(
        paymentLink: String,
        token: MixinTokenItem? = nil,
        onSuccess: @escaping @MainActor (ExternalTransfer, MixinTokenItem, WithdrawFeeItem?, Payment.WithdrawalDestination) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let transfer = try await ExternalTransfer(string: paymentLink)
                let tokenItem: MixinTokenItem = if let token {
                    token
                } else {
                    try await syncToken(assetID: transfer.assetID)
                }
                
                if let token {
                    if transfer.amount > 0 {
                        if token.assetID != token.assetID {
                            throw ValidationError.invalidFormat
                        }
                    } else {
                        if token.chainID != token.chainID {
                            throw ValidationError.invalidFormat
                        }
                    }
                }
                
                let temporaryAddress = try await checkAddress(
                    chainID: tokenItem.chainID,
                    assetID: tokenItem.assetID,
                    destination: transfer.destination,
                    tag: nil
                )
                
                let withdrawFeeItem: WithdrawFeeItem?
                if transfer.amount > 0 {
                    if transfer.amount > tokenItem.decimalBalance {
                        throw ValidationError.insufficientBalance(tokenItem)
                    }
                    
                    let feeItem = try await checkFee(
                        assetID: tokenItem.assetID,
                        amount: transfer.amount,
                        destination: temporaryAddress.destination)
                    withdrawFeeItem = WithdrawFeeItem(amount: feeItem.amount, tokenItem: feeItem.tokenItem)
                } else {
                    withdrawFeeItem = nil
                }
                
                let withdrawDestination = getWithdrawalDestination(chainID: tokenItem.chainID, temporaryAddress: temporaryAddress)
                
                await MainActor.run {
                    onSuccess(transfer, tokenItem, withdrawFeeItem, withdrawDestination)
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
        onSuccess: @escaping @MainActor (Payment.WithdrawalDestination, TemporaryAddress) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let temporaryAddress = try await checkAddress(
                    chainID: chainID,
                    assetID: assetID,
                    destination: destination,
                    tag: tag
                )
                let withdrawDestination = getWithdrawalDestination(chainID: chainID, temporaryAddress: temporaryAddress)
                
                await MainActor.run {
                    onSuccess(withdrawDestination, temporaryAddress)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    private static func getWithdrawalDestination(chainID: String, temporaryAddress: TemporaryAddress) -> Payment.WithdrawalDestination {
        let localAddress = AddressDAO.shared.getAddress(chainId: chainID, destination: temporaryAddress.destination, tag: temporaryAddress.tag)
        return if let localAddress {
            .address(localAddress)
        } else {
            .temporary(temporaryAddress)
        }
    }
    
    private static func checkFee(
        assetID: String,
        amount: Decimal,
        destination: String
    ) async throws -> WithdrawFeeItem {
        let fees = try await SafeAPI.fees(
            assetID: assetID,
            destination: destination
        )
        
        for fee in fees {
            let feeItem = try await syncFeeToken(fee: fee)
            let isFeeSufficient = if feeItem.tokenItem.assetID == assetID {
                (amount + feeItem.amount) <= feeItem.tokenItem.decimalBalance
            } else {
                feeItem.amount <= feeItem.tokenItem.decimalBalance
            }
            
            if isFeeSufficient {
                return feeItem
            }
        }
        
        guard let firstFee = fees.first else {
            throw MixinAPIResponseError.withdrawSuspended
        }
        let feeItem = try await syncFeeToken(fee: firstFee)
        throw ValidationError.insufficientFee(feeItem)
    }
    
    private static func checkAddress(
        chainID: String,
        assetID: String,
        destination: String,
        tag: String?
    ) async throws -> TemporaryAddress {
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
        return TemporaryAddress(destination: response.destination, tag: response.tag ?? "")
    }
    
    
    
    private static func syncFeeToken(fee: WithdrawFee) async throws -> WithdrawFeeItem {
        let feeToken = try await syncToken(assetID: fee.assetID)
        guard let feeItem = WithdrawFeeItem(amountString: fee.amount, tokenItem: feeToken) else {
            Logger.general.error(category: "AddressValidator", message: "Invalid fee amount: \(fee.amount), fee token: \(feeToken.assetID)")
            throw MixinAPIResponseError.internalServerError
        }
        
        return feeItem
    }
    
    private static func syncToken(assetID: String) async throws -> MixinTokenItem {
        var token: MixinTokenItem
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
