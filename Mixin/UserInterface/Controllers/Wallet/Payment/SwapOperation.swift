import Foundation
import MixinServices

final class SwapOperation {
    
    private let operation: any PaymentOperation
    
    let sendToken: BalancedSwapToken
    let sendAmount: Decimal
    
    let receiveToken: SwapToken
    let receiveAmount: Decimal
    
    let destination: Destination
    
    let memo: String?
    
    init(
        operation: any PaymentOperation, sendToken: BalancedSwapToken,
        sendAmount: Decimal, receiveToken: SwapToken,
        receiveAmount: Decimal, destination: Destination,
        memo: String?
    ) {
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

extension SwapOperation {
    
    protocol PaymentOperation {
        func start(pin: String) async throws
    }
    
    enum Destination {
        case mixin(UserItem)
        case web3(Web3Destination)
    }
    
    struct Web3Destination {
        let displayReceiver: UserItem
        let depositDestination: String
        let fee: Web3TransferOperation.DisplayFee
        let feeTokenSymbol: String
        let senderAddress: Web3Address
        let senderAddressLabel: AddressLabel?
    }
    
}
