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
            try withSolanaStringPointer { key in
                solana_public_key_from_seed(seed.baseAddress, seed.count, &key)
            }
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
                try withSolanaStringPointer { signature in
                    solana_sign_message(seed.baseAddress,
                                        seed.count,
                                        message.baseAddress,
                                        message.count,
                                        &signature)
                }
            }
        }
    }
    
    static func tokenAssociatedAccount(owner: String, mint: String) throws -> String {
        try owner.withCString { owner in
            try mint.withCString { mint in
                try withSolanaStringPointer { account in
                    solana_associated_token_account(owner, mint, &account)
                }
            }
        }
    }
    
    fileprivate static func withSolanaStringPointer(_ assignment: (inout UnsafePointer<CChar>?) -> SolanaErrorCode) throws -> String {
        var pointer: UnsafePointer<CChar>?
        let result = assignment(&pointer)
        guard result == SolanaErrorCodeSuccess else {
            throw Error.code(result)
        }
        guard let pointer else {
            throw Error.nullResult
        }
        let string = String(cString: UnsafePointer(pointer))
        solana_free_string(pointer)
        return string
    }
    
    fileprivate static func withOptionalUnsafePointer<T, Result>(
        to value: T?,
        _ body: (UnsafePointer<T>?) throws -> Result
    ) rethrows -> Result {
        if let value {
            try withUnsafePointer(to: value) { pointer in
                try body(pointer)
            }
        } else {
            try body(nil)
        }
    }
    
}

extension Solana {
    
    struct BalanceChange {
        let amount: Decimal
        let assetKey: String
    }
    
    final class Transaction {
        
        enum Encoding {
            case base64
            case base64URL
        }
        
        let rawTransaction: String
        let change: BalanceChange?
        
        private let pointer: UnsafeRawPointer
        
        init?(string: String, encoding: Encoding) {
            let transactionData = switch encoding {
            case .base64:
                Data(base64Encoded: string)
            case .base64URL:
                Data(base64URLEncoded: string)
            }
            guard let transactionData else {
                return nil
            }
            let pointer = transactionData.withUnsafeBytes { data in
                solana_deserialize_transaction(data.baseAddress, data.count)
            }
            guard let pointer else {
                return nil
            }
            
            self.rawTransaction = switch encoding {
            case .base64:
                string
            case .base64URL:
                transactionData.base64EncodedString()
            }
            self.change = nil
            self.pointer = pointer
        }
        
        init(
            from: String,
            to: String,
            createAssociatedTokenAccountForReceiver createAccount: Bool,
            amount: UInt64,
            priorityFee: PriorityFee?,
            token: Web3Token,
            change: BalanceChange
        ) throws {
            let isSendingSOL = token.chainID == Web3Token.ChainID.solana
                && (token.assetKey == Web3Token.AssetKey.sol || token.assetKey == Web3Token.AssetKey.wrappedSOL)
            let solanaPriorityFee: SolanaPriorityFee? = if let fee = priorityFee {
                SolanaPriorityFee(price: fee.unitPrice, limit: fee.unitLimit)
            } else {
                nil
            }
            var transaction: UnsafeRawPointer?
            let result = from.withCString { from in
                to.withCString { to in
                    withOptionalUnsafePointer(to: solanaPriorityFee) { priorityFee in
                        if isSendingSOL {
                            solana_new_sol_transaction(from, to, amount, priorityFee, &transaction)
                        } else {
                            token.assetKey.withCString { mint in
                                solana_new_spl_transaction(from, to, createAccount, mint, amount, priorityFee, &transaction)
                            }
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
            let rawTransaction = try withSolanaStringPointer { rawTransaction in
                solana_base64_encode_transaction(transaction, &rawTransaction)
            }
            
            self.rawTransaction = rawTransaction
            self.change = change
            self.pointer = transaction
        }
        
        deinit {
            solana_free_transaction(pointer)
        }
        
        func sign(withPrivateKeyFrom seed: Data, recentBlockhash: Data) throws -> String {
            try recentBlockhash.withUnsafeBytes { recentBlockhash in
                try seed.withUnsafeBytes { seed in
                    try withSolanaStringPointer { signature in
                        solana_sign_transaction(pointer,
                                                recentBlockhash.baseAddress,
                                                recentBlockhash.count,
                                                seed.baseAddress,
                                                seed.count,
                                                &signature)
                    }
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