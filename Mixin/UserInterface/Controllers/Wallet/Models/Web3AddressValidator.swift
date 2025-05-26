import Foundation
import web3
import MixinServices

enum Web3AddressValidator {
    
    enum ValidationError: Error, LocalizedError {
        
        case invalidFormat
        case mismatchedDestination
        case insufficientBalance(Web3TokenItem)
        case insufficientFee(Web3WithdrawFeeItem)
        case insufficientForSolRent
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                R.string.localizable.invalid_payment_link()
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
    
    static func validateWithdrawLink(
        paymentLink: String,
        token: Web3TokenItem,
        payment: Web3SendingTokenPayment,
        onSuccess: @escaping @MainActor (ExternalTransfer, Web3TransferOperation, Web3SendingTokenToAddressPayment) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                guard let walletAddress = Web3AddressDAO.shared.address(walletID: token.walletID, chainID: token.chainID)?.destination else {
                    throw TransferLinkError.assetNotFound
                }
                
                // Parse withdraw link
                let transfer = try await ExternalTransfer(string: paymentLink) { assetKey in
                    Web3TokenDAO.shared.assetID(assetKey: assetKey)
                } resolveAmount: { (_, amount) in
                    ExternalTransfer.resolve(atomicAmount: amount, with: Int(token.precision))
                }
                
                // Check if the link token matches the current token
                let linkToken = try await syncToken(walletID: token.walletID, walletAddress: walletAddress, assetID: transfer.assetID)
                if transfer.amount > 0 {
                    if transfer.assetID != linkToken.assetID {
                        throw ValidationError.invalidFormat
                    }
                } else {
                    if token.chainID != linkToken.chainID {
                        throw ValidationError.invalidFormat
                    }
                }
                
                // Check address format
                _ = try await checkAddress(chainID: token.chainID, assetID: token.assetID, destination: transfer.destination)
                
                // Query address lable
                let localAddress = AddressDAO.shared.getAddress(chainId: token.chainID, destination: transfer.destination, tag: "")
                let withdrawDestination: Web3SendingTokenToAddressPayment.AddressType = if let localAddress {
                    .addressBook(label: localAddress.label)
                } else {
                    .arbitrary
                }
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    to: withdrawDestination,
                    address: transfer.destination
                )
                
                // Validate amount and fee
                let operation = try await validateAmountAndFee(payment: addressPayment, amount: transfer.amount)
                await MainActor.run {
                    onSuccess(transfer, operation, addressPayment)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    static func validate(
        destination: String,
        token: Web3TokenItem,
        payment: Web3SendingTokenPayment,
        onSuccess: @escaping @MainActor (Web3SendingTokenToAddressPayment) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let address = try await checkAddress(
                    chainID: token.chainID,
                    assetID: token.assetID,
                    destination: destination
                )
                
                let localAddress = AddressDAO.shared.getAddress(chainId: token.chainID, destination: destination, tag: "")
                let withdrawDestination: Web3SendingTokenToAddressPayment.AddressType = if let localAddress {
                    .addressBook(label: localAddress.label)
                } else {
                    .arbitrary
                }
                let addressPayment = Web3SendingTokenToAddressPayment(
                    payment: payment,
                    to: withdrawDestination,
                    address: destination
                )
                
                await MainActor.run {
                    onSuccess(addressPayment)
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    private static func validateAmountAndFee(payment: Web3SendingTokenToAddressPayment, amount: Decimal) async throws -> Web3TransferOperation {
        let token = payment.token
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
        
        if amount > 0 {
            _ = try await checkFee(amount: amount, payment: payment, operation: operation)
        }
        
        if amount > token.decimalBalance {
            throw ValidationError.insufficientBalance(token)
        } else if amount < minimumTransferAmount {
            throw ValidationError.insufficientForSolRent
        }
        
        return operation
    }
    
    private static func checkAddress(
        chainID: String,
        assetID: String,
        destination: String
    ) async throws -> String {
        let response = try await ExternalAPI.checkAddress(
            chainID: chainID,
            assetID: assetID,
            destination: destination,
            tag: nil
        )
        guard destination.lowercased() == response.destination.lowercased() else {
            throw ValidationError.mismatchedDestination
        }
        return response.destination
    }
    
    private static func checkFee(
        amount: Decimal,
        payment: Web3SendingTokenToAddressPayment,
        operation: Web3TransferOperation
    ) async throws -> Web3WithdrawFeeItem {
        let fee = try await operation.loadFee()
        let feeItem = Web3WithdrawFeeItem(amount: fee.amount, tokenItem: fee.token)
        
        let feeInsufficient = if payment.sendingNativeToken {
            amount > payment.token.decimalBalance - fee.amount
        } else {
            fee.amount > fee.token.decimalBalance
        }
        if feeInsufficient {
            throw ValidationError.insufficientFee(feeItem)
        }
        
        return feeItem
    }
    
    private static func syncToken(walletID: String, walletAddress: String, assetID: String) async throws -> Web3TokenItem {
        if let localToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID) {
            return localToken
        } else {
            let remoteToken = try await RouteAPI.asset(assetID: assetID, address: walletAddress)
            Web3TokenDAO.shared.save(tokens: [remoteToken])
            let chain = ChainDAO.shared.chain(chainId: remoteToken.chainID)
            return Web3TokenItem(token: remoteToken, hidden: false, chain: chain)
        }
    }
}
