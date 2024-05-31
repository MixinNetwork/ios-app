import Foundation

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
    
}

extension Solana {
    
    struct BalanceChange {
        let amount: Decimal
        let assetKey: String
    }
    
    final class Transaction {
        
        let rawTransaction: String
        let change: BalanceChange?
        
        private let pointer: UnsafeMutableRawPointer
        
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
            self.rawTransaction = rawTransaction
            self.pointer = pointer
            self.change = {
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
