import Foundation
import web3
import MixinServices

enum Web3AddressValidator {
    
    enum Web3TransferValidationResult {
        case address(type: Web3SendingTokenToAddressPayment.AddressType, address: String)
        case insufficientBalance(transferring: BalanceRequirement, fee: BalanceRequirement)
        case solAmountTooSmall
        case transfer(operation: Web3TransferOperation, label: String?)
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
                        Web3TokenDAO.shared.save(tokens: [remoteToken])
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
                    let (type, address) = try await validate(
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
                        to: type,
                        address: address
                    )
                    let operation: Web3TransferOperation = switch chain.specification {
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
                            onSuccess(.transfer(operation: operation, label: type.addressLabel))
                        } else {
                            onSuccess(.insufficientBalance(transferring: transferRequirement, fee: feeRequirement))
                        }
                    }
                } else {
                    let (type, address) = try await validate(
                        chainID: link.chainID,
                        assetID: payment.token.assetID,
                        destination: link.destination
                    )
                    await MainActor.run {
                        onSuccess(.address(type: type, address: address))
                    }
                }
            } catch TransferLinkError.notTransferLink {
                do {
                    let (type, address) = try await validate(
                        chainID: payment.chain.chainID,
                        assetID: payment.token.assetID,
                        destination: string
                    )
                    await MainActor.run {
                        onSuccess(.address(type: type, address: address))
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
    ) async throws -> (type: Web3SendingTokenToAddressPayment.AddressType, address: String) {
        if let address = AddressDAO.shared.getAddress(chainId: chainID, destination: destination, tag: "") {
            return (type: .addressBook(label: address.label), address.destination)
        } else if let entry = DepositEntryDAO.shared.primaryEntry(ofChainWith: chainID), entry.destination == destination {
            return (type: .privacyWallet, address: entry.destination)
        } else {
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
            return (type: .arbitrary, destination)
        }
    }
    
}
