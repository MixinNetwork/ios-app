import Foundation
import MixinServices

class SwapPaymentOperation {
    
    private let operation: PaymentOperation
    
    let sendToken: BalancedSwapToken
    let sendAmount: Decimal
    
    let receiveToken: SwapToken
    let receiveAmount: Decimal
    
    let destination: SwapDestination
    
    let memo: String?
    
    init(operation: PaymentOperation, sendToken: BalancedSwapToken, sendAmount: Decimal, receiveToken: SwapToken, receiveAmount: Decimal, destination: SwapDestination, memo: String?) {
        self.operation = operation
        self.sendToken = sendToken
        self.sendAmount = sendAmount
        self.receiveToken = receiveToken
        self.receiveAmount = receiveAmount
        self.destination = destination
        self.memo = memo
    }
    
    func start(pin: String) async throws {
        try await operation.start(pin: pin)
    }
}

extension SwapPaymentOperation {
    
    enum SwapDestination {
        
        case user(UserItem)
        
        case address(String, Web3TransferOperation.Fee, String)
        
    }
}
