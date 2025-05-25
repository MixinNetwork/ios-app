import Foundation
import web3
import MixinServices

enum Web3AddressValidator {
    
    enum ValidationError: Error, LocalizedError {
        
        case mismatchedDestination
        case insufficientBalance(Web3TokenItem)
        case insufficientFee(Web3WithdrawFeeItem)
        case insufficientForSolRent
        
        var errorDescription: String? {
            switch self {
            case .mismatchedDestination:
                R.string.localizable.invalid_address()
            case .insufficientBalance:
                R.string.localizable.insufficient_balance()
            case .insufficientFee(let fee):
                R.string.localizable.insufficient_fee_description(
                    fee.localizedAmountWithSymbol,
                    fee.tokenItem.chain?.name ?? ""
                )
            case .insufficientForSolRent:
                R.string.localizable.send_sol_for_rent(
                    CurrencyFormatter.localizedString(
                        from: Solana.accountCreationCost,
                        format: .precision,
                        sign: .never,
                    )
                )
            }
        }
    }
    
    static func validateAmountAndLoadFee(
        payment: Web3SendingTokenToAddressPayment,
        amount: Decimal,
        onSuccess: @escaping @MainActor (Web3TransferOperation) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        let token = payment.token
        
        Task {
            do {
                let operation: Web3TransferOperation
                var minimumTransferAmount: Decimal = 0
                
                switch payment.chain.specification {
                case .evm(let chainID):
                    operation = try EVMTransferToAddressOperation(
                        evmChainID: chainID,
                        payment: payment,
                        decimalAmount: amount
                    )
                case .solana:
                    operation = try SolanaTransferToAddressOperation(payment: payment, decimalAmount: amount)
                    if payment.sendingNativeToken {
                        let accountExists = try await RouteAPI.solanaAccountExists(pubkey: payment.toAddress)
                        minimumTransferAmount = accountExists ? 0 : Solana.accountCreationCost
                    }
                }
                
                let fee = try await operation.loadFee()
                let feeToken = fee.token
                let feeAmount = fee.amount
                
                let balanceInsufficient = amount > token.decimalBalance
                let feeInsufficient = if payment.sendingNativeToken {
                    amount > token.decimalBalance - feeAmount
                } else {
                    fee.amount > feeToken.decimalBalance
                }
                
                if feeInsufficient {
                    throw ValidationError.insufficientFee(Web3WithdrawFeeItem(amount: feeAmount, tokenItem: feeToken))
                } else if balanceInsufficient {
                    throw ValidationError.insufficientBalance(token)
                } else if amount < minimumTransferAmount {
                    throw ValidationError.insufficientForSolRent
                }
                
                await MainActor.run {
                    onSuccess(operation)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
}
