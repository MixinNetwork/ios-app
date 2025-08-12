import Foundation
import MixinServices

enum SequentialWalletPathGenerator {
    
    enum GenerationError: Error {
        case missingDefaultWallet
        case invalidPath
        case mismatchIndex
    }
    
    static func nextPathIndex(walletCategory category: Web3Wallet.Category) throws -> Int {
        let paths = Web3AddressDAO.shared.paths(walletCategory: category)
        if paths.isEmpty {
            throw GenerationError.missingDefaultWallet
        }
        
        let evmPathRegex = try TIP.ClassicWalletDerivation.evmPathRegex()
        let solanaPathRegex = try TIP.ClassicWalletDerivation.solanaPathRegex()
        
        var maxEVMIndex: Int = 0
        var maxSolanaIndex: Int = 0
        for path in paths {
            let full = NSRange(path.startIndex..<path.endIndex, in: path)
            if let match = evmPathRegex.firstMatch(in: path, range: full) {
                guard let indexRange = Range(match.range(at: 1), in: path) else {
                    throw GenerationError.invalidPath
                }
                guard let index = Int(path[indexRange]) else {
                    throw GenerationError.invalidPath
                }
                maxEVMIndex = max(maxEVMIndex, index)
            } else if let match = solanaPathRegex.firstMatch(in: path, range: full) {
                guard let indexRange = Range(match.range(at: 1), in: path) else {
                    throw GenerationError.invalidPath
                }
                guard let index = Int(path[indexRange]) else {
                    throw GenerationError.invalidPath
                }
                maxSolanaIndex = max(maxSolanaIndex, index)
            } else {
                throw GenerationError.invalidPath
            }
        }
        
        guard maxEVMIndex == maxSolanaIndex else {
            throw GenerationError.mismatchIndex
        }
        return maxEVMIndex + 1
    }
    
}
