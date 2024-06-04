import Foundation
import MixinServices

enum Solana {
    
    enum Error: Swift.Error {
        case nullResult
        case code(SolanaErrorCode)
    }
    
    static let lamportsPerSOL = Decimal(SOLANA_LAMPORTS_PER_SOL)
    
    static func publicKey(seed: Data) throws -> String {
        try seed.withUnsafeBytes { seed in
            var key: UnsafePointer<CChar>?
            let result = solana_public_key_from_seed(seed.baseAddress, seed.count, &key)
            guard result == SolanaErrorCodeSuccess else {
                throw Error.code(result)
            }
            guard let key else {
                throw Error.nullResult
            }
            let publicKey = String(cString: UnsafePointer(key))
            solana_free_string(key)
            return publicKey
        }
    }
    
    static func isValidPublicKey(string: String) -> Bool {
        string.withCString { string in
            solana_is_valid_public_key(string)
        }
    }
    
    static func sign(message: Data, withPrivateKeyFrom seed: Data) throws -> String {
        try message.withUnsafeBytes { message in
            try seed.withUnsafeBytes { seed in
                var signaturePtr: UnsafePointer<CChar>?
                let result = solana_sign_message(seed.baseAddress,
                                                 seed.count,
                                                 message.baseAddress,
                                                 message.count,
                                                 &signaturePtr)
                guard result == SolanaErrorCodeSuccess else {
                    throw Error.code(result)
                }
                guard let signaturePtr else {
                    throw Error.nullResult
                }
                let signature = String(cString: UnsafePointer(signaturePtr))
                solana_free_string(signaturePtr)
                return signature
            }
        }
    }
    
    static func tokenAssociatedAccount(owner: String, mint: String) throws -> String {
        try owner.withCString { owner in
            try mint.withCString { mint in
                var accountPtr: UnsafePointer<CChar>?
                let result = solana_associated_token_account(owner, mint, &accountPtr)
                guard result == SolanaErrorCodeSuccess else {
                    throw Error.code(result)
                }
                guard let accountPtr else {
                    throw Error.nullResult
                }
                let account = String(cString: UnsafePointer(accountPtr))
                solana_free_string(accountPtr)
                return account
            }
        }
    }
    
}

extension Solana {
    
    struct BalanceChange {
        let amount: Decimal
        let assetKey: String
    }
    
    final class Transaction {
        
        let rawTransaction: String
        let change: BalanceChange?
        
        private let pointer: UnsafeRawPointer
        
        init?(rawTransaction: String) {
            guard let transactionData = Data(base64Encoded: rawTransaction) else {
                return nil
            }
            let pointer = transactionData.withUnsafeBytes { data in
                solana_deserialize_transaction(data.baseAddress, data.count)
            }
            guard let pointer else {
                return nil
            }
            let change: BalanceChange? = {
                var change: UInt64 = 0
                var mintPtr: UnsafePointer<CChar>?
                let result = solana_balance_change(pointer, &change, &mintPtr)
                guard result == SolanaErrorCodeSuccess, let mintPtr else {
                    return nil
                }
                let amount = Decimal(change) / Solana.lamportsPerSOL
                let mint = String(cString: UnsafePointer(mintPtr))
                solana_free_string(mintPtr)
                return BalanceChange(amount: amount, assetKey: mint)
            }()
            
            self.rawTransaction = rawTransaction
            self.change = change
            self.pointer = pointer
        }
        
        init(
            from: String,
            to: String,
            createAssociatedTokenAccountForReceiver: Bool,
            amount: UInt64,
            token: Web3Token,
            change: BalanceChange
        ) throws {
            let isSendingSOL = token.chainID == Web3Token.ChainID.solana
                && (token.assetKey == Web3Token.AssetKey.sol || token.assetKey == Web3Token.AssetKey.wrappedSOL)
            var transaction: UnsafeRawPointer?
            let result = from.withCString { from in
                to.withCString { to in
                    if isSendingSOL {
                        solana_new_sol_transaction(from, to, amount, &transaction)
                    } else {
                        token.assetKey.withCString { mint in
                            solana_new_spl_transaction(from, 
                                                       to,
                                                       createAssociatedTokenAccountForReceiver,
                                                       mint,
                                                       amount,
                                                       &transaction)
                        }
                    }
                }
            }
            guard result == SolanaErrorCodeSuccess else {
                throw Error.code(result)
            }
            guard let transaction else {
                throw Error.nullResult
            }
            self.rawTransaction = ""
            self.change = change
            self.pointer = transaction
        }
        
        deinit {
            solana_free_transaction(pointer)
        }
        
        func sign(withPrivateKeyFrom seed: Data, recentBlockhash: Data) throws -> String {
            try recentBlockhash.withUnsafeBytes { recentBlockhash in
                try seed.withUnsafeBytes { seed in
                    var signaturePtr: UnsafePointer<CChar>?
                    let result = solana_sign_transaction(pointer,
                                                         recentBlockhash.baseAddress,
                                                         recentBlockhash.count,
                                                         seed.baseAddress,
                                                         seed.count,
                                                         &signaturePtr)
                    guard result == SolanaErrorCodeSuccess else {
                        throw Error.code(result)
                    }
                    guard let signaturePtr else {
                        throw Error.nullResult
                    }
                    let signature = String(cString: UnsafePointer(signaturePtr))
                    solana_free_string(signaturePtr)
                    return signature
                }
            }
        }
        
        func fee(lamportsPerSignature: UInt64) -> Decimal? {
            var lamports: UInt64 = 0
            let result = solana_calculate_fee(pointer, lamportsPerSignature, &lamports)
            guard result == SolanaErrorCodeSuccess else {
                return nil
            }
            return Decimal(lamports) / Solana.lamportsPerSOL
        }
        
    }
    
}
