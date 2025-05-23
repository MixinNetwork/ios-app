import Foundation
import web3
import MixinServices

enum Web3AddressValidator {
    
    enum ValidationError: Error, LocalizedError {
        
        case mismatchedDestination
        case insufficientBalance(Web3TokenItem)
        case insufficientFee(Web3WithdrawFeeItem)
        case insufficientForSolRent
        
    }
    
    static func validateAddressAndLoadFee(
        payment: Web3SendingTokenToAddressPayment,
        destination: String,
        amount: Decimal?,
        onSuccess: @escaping @MainActor (Web3TransferOperation?) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        let token = payment.token
        
        Task {
            do {
                let verifiedAddress: String
                let minimumTransferAmount: Decimal
                
                switch payment.chain.kind {
                case .evm:
                    let ethereumAddress = EthereumAddress(destination)
                    if destination.count != 42 || ethereumAddress.asNumber() == nil {
                        throw ValidationError.mismatchedDestination
                    } else {
                        verifiedAddress = ethereumAddress.toChecksumAddress()
                    }
                    minimumTransferAmount = 0
                case .solana:
                    if Solana.isValidPublicKey(string: destination) {
                        verifiedAddress = destination
                    } else {
                        throw ValidationError.mismatchedDestination
                    }
                    
                    if payment.sendingNativeToken {
                        let accountExists = try await RouteAPI.solanaAccountExists(pubkey: payment.toAddress)
                        minimumTransferAmount = accountExists ? 0 : Solana.accountCreationCost
                    } else {
                        minimumTransferAmount = 0
                    }
                }
                
                if let amount, amount > 0 {
                    let operation = switch payment.chain.specification {
                    case .evm(let chainID):
                        try EVMTransferToAddressOperation(
                            evmChainID: chainID,
                            payment: payment,
                            decimalAmount: amount
                        )
                    case .solana:
                        try SolanaTransferToAddressOperation(payment: payment, decimalAmount: amount)
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
                } else {
                    await MainActor.run {
                        onSuccess(nil)
                    }
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
}
