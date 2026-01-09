import Foundation
import MixinServices

enum SequentialWalletPathGenerator {
    
    enum GenerationError: Error {
        case missingDefaultWallet
        case invalidPath
        case mismatchIndex
    }
    
    static func maxIndex(paths: [String]) throws -> Int {
        let evmPathRegex = try DerivationPath.evmPathRegex()
        let solanaPathRegex = try DerivationPath.solanaPathRegex()
        
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
        return maxEVMIndex
    }
    
    static func nextPathIndex(walletCategory category: Web3Wallet.Category) throws -> Int {
        let paths = Web3AddressDAO.shared.paths(walletCategory: category)
        if paths.isEmpty {
            throw GenerationError.missingDefaultWallet
        }
        let index = try maxIndex(paths: paths)
        return index + 1
    }
    
}
