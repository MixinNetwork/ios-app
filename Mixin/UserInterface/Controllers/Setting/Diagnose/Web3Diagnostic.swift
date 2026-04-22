import Foundation

enum Web3Diagnostic {
    
    @MainActor
    static var usesLowEVMFeeOnce = false
    
    @MainActor
    static var disableGasless = false
    
}

extension Web3Diagnostic {
    
    enum DiagnosticError: Error {
        case gaslessDisabled
    }
    
}
