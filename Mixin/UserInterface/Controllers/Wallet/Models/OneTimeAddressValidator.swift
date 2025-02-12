import Foundation
import MixinServices

enum OneTimeAddressValidator {
    
    enum ValidationError: Error, LocalizedError {
        
        case mismatchedDestination
        case mismatchedTag
        case insufficientFee(WithdrawFeeItem?)
        
        var errorDescription: String? {
            switch self {
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
            }
        }
        
    }
    
    static func validate(
        assetID: String,
        destination: String,
        tag: String?,
        onSuccess: @escaping @MainActor (TemporaryAddress) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let address = try await validatedAddress(
                    assetID: assetID,
                    destination: destination,
                    tag: tag
                )
                await MainActor.run {
                    onSuccess(address)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    static func validateAddressAndLoadFee(
        assetID: String,
        destination: String,
        tag: String?,
        onSuccess: @escaping @MainActor (TemporaryAddress, WithdrawFeeItem) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let address = try await validatedAddress(
                    assetID: assetID,
                    destination: destination,
                    tag: tag
                )
                let fees = try await SafeAPI.fees(
                    assetID: assetID,
                    destination: address.destination
                )
                guard !fees.isEmpty else {
                    throw MixinAPIResponseError.withdrawSuspended
                }
                let allAssetIDs = fees.map(\.assetID)
                let tokensMap = TokenDAO.shared.tokenItems(with: allAssetIDs)
                    .reduce(into: [:]) { result, item in
                        result[item.assetID] = item
                    }
                let feeItems: [WithdrawFeeItem] = fees.lazy.compactMap { fee in
                    if let token = tokensMap[fee.assetID] {
                        WithdrawFeeItem(amountString: fee.amount, tokenItem: token)
                    } else {
                        nil
                    }
                }
                let feeItem = feeItems.first { item in
                    item.tokenItem.decimalBalance >= item.amount
                }
                guard let feeItem else {
                    throw ValidationError.insufficientFee(feeItems.first)
                }
                await MainActor.run {
                    onSuccess(address, feeItem)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    private static func validatedAddress(
        assetID: String,
        destination: String,
        tag: String?
    ) async throws -> TemporaryAddress {
        let response = try await ExternalAPI.checkAddress(
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
    
}
