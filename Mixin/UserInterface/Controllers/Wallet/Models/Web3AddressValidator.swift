import Foundation
import web3
import MixinServices

enum Web3AddressValidator {
    
    enum Web3TransferValidationResult {
        case address(address: String, label: AddressLabel?)
        case insufficientBalance(transferring: BalanceRequirement, fee: BalanceRequirement)
        case solAmountTooSmall
        case transfer(operation: Web3TransferOperation, toAddressLabel: AddressLabel?)
    }
    
    enum ValidationError: Error, LocalizedError {
        
        case invalidFormat
        case unknownAssetKey
        case mismatchedDestination
        case mismatchedTag
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                R.string.localizable.invalid_payment_link()
            case .unknownAssetKey:
                R.string.localizable.insufficient_balance()
            case .mismatchedDestination, .mismatchedTag:
                R.string.localizable.invalid_address()
            }
        }
        
    }
    
    static func validate(
        string: String,
        payment: Web3SendingTokenPayment,
        onSuccess: @escaping @MainActor (Web3TransferValidationResult) -> Void,
        onFailure: @escaping @MainActor (Error) -> Void
    ) {
        Task {
            do {
                let walletID = payment.wallet.walletID
                
                // Web3 wallet don’t support Bitcoin at the moment, so there’s no need to check if the link is for Lightning.
                let link = try ExternalTransfer(string: string)
                guard payment.chain.chainID == link.chainID else {
                    throw ValidationError.invalidFormat
                }
                let chain = payment.chain
                
                let linkToken: Web3TokenItem
                switch link.tokenID {
                case .assetID(let id):
                    if let localToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: id) {
                        linkToken = localToken
                    } else {
                        guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: link.chainID) else {
                            throw ValidationError.invalidFormat
                        }
                        let remoteToken = try await RouteAPI.asset(assetID: id, address: address.destination)
                        Web3TokenDAO.shared.save(
                            tokens: [remoteToken], 
                            outputBasedAssetIDs: [AssetID.btc],
                            zeroOutOthers: false
                        )
                        let chain = ChainDAO.shared.chain(chainId: remoteToken.chainID)
                        linkToken = Web3TokenItem(token: remoteToken, hidden: false, chain: chain)
                    }
                case .assetKey(let key):
                    if let localToken = Web3TokenDAO.shared.token(walletID: walletID, assetKey: key) {
                        linkToken = localToken
                    } else {
                        throw ValidationError.unknownAssetKey
                    }
                }
                
                let amount = try await link.decimalAmount {
                    // Since the amount is decoded from the link, it should be calculated using the token specified in the link.
                    Int(linkToken.precision)
                }
                if let amount, amount > 0 {
                    if linkToken.assetID != payment.token.assetID {
                        throw ValidationError.invalidFormat
                    }
                    let token = linkToken
                    let (address, label) = try await validate(
                        chainID: link.chainID,
                        assetID: token.assetID,
                        destination: link.destination
                    )
                    if chain.kind == .solana && payment.sendingNativeToken {
                        let accountExists = try await RouteAPI.solanaAccountExists(pubkey: address)
                        if !accountExists && amount < Solana.accountCreationCost {
                            await MainActor.run {
                                onSuccess(.solAmountTooSmall)
                            }
                            return
                        }
                    }
                    let addressPayment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        toAddress: address,
                        toAddressLabel: label
                    )
                    let operation: Web3TransferOperation = switch chain.specification {
                    case .bitcoin:
                        try BitcoinTransferToAddressOperation(
                            payment: addressPayment,
                            decimalAmount: amount
                        )
                    case let .evm(chainID):
                        try EVMTransferToAddressOperation(
                            evmChainID: chainID,
                            payment: addressPayment,
                            decimalAmount: amount
                        )
                    case .solana:
                        try SolanaTransferToAddressOperation(
                            payment: addressPayment,
                            decimalAmount: amount
                        )
                    }
                    let fee = try await operation.loadFee()
                    let transferRequirement = BalanceRequirement(token: token, amount: amount)
                    let feeRequirement = BalanceRequirement(token: operation.feeToken, amount: fee.tokenAmount)
                    let requirements = transferRequirement.merging(with: feeRequirement)
                    let isBalanceSufficient = requirements.allSatisfy(\.isSufficient)
                    await MainActor.run {
                        if isBalanceSufficient {
                            onSuccess(.transfer(operation: operation, toAddressLabel: label))
                        } else {
                            onSuccess(.insufficientBalance(transferring: transferRequirement, fee: feeRequirement))
                        }
                    }
                } else {
                    let (address, label) = try await validate(
                        chainID: link.chainID,
                        assetID: payment.token.assetID,
                        destination: link.destination
                    )
                    await MainActor.run {
                        onSuccess(.address(address: address, label: label))
                    }
                }
            } catch TransferLinkError.notTransferLink {
                do {
                    let (address, label) = try await validate(
                        chainID: payment.chain.chainID,
                        assetID: payment.token.assetID,
                        destination: string
                    )
                    await MainActor.run {
                        onSuccess(.address(address: address, label: label))
                    }
                } catch {
                    await MainActor.run {
                        onFailure(error)
                    }
                }
            } catch {
                await MainActor.run {
                    onFailure(error)
                }
            }
        }
    }
    
    private static func validate(
        chainID: String,
        assetID: String,
        destination: String,
    ) async throws -> (address: String, label: AddressLabel?) {
        let response = try await ExternalAPI.checkAddress(
            chainID: chainID,
            assetID: assetID,
            destination: destination,
            tag: nil
        )
        guard destination.lowercased() == response.destination.lowercased() else {
            throw ValidationError.mismatchedDestination
        }
        guard response.tag.isNilOrEmpty else {
            throw ValidationError.mismatchedTag
        }
        if let entry = DepositEntryDAO.shared.primaryEntry(ofChainWith: chainID),
           entry.destination == response.destination
        {
            return (address: entry.destination, label: .wallet(.privacy))
        } else if let wallet = Web3WalletDAO.shared.wallet(destination: response.destination),
                  let address = Web3AddressDAO.shared.address(walletID: wallet.walletID, chainID: chainID)
        {
            return (address: address.destination, label: .wallet(.common(wallet)))
        } else if let wallet = SafeWalletDAO.shared.wallet(safeAddress: response.destination) {
            return (address: response.destination, label: .wallet(.safe(wallet)))
        } else if let address = AddressDAO.shared.address(chainID: chainID, destination: response.destination, tag: "") {
            return (address: address.destination, label: .addressBook(address.label))
        } else {
            return (address: response.destination, label: nil)
        }
    }
    
}
