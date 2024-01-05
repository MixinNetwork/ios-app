import Foundation
import MixinServices

protocol WithdrawableAddress {
    
    var destination: String { get }
    var tag: String { get }
    
}

extension WithdrawableAddress {
    
    public var fullRepresentation: String {
        Address.fullRepresentation(destination: destination, tag: tag)
    }
    
    public var compactRepresentation: String {
        Address.compactRepresentation(of: fullRepresentation)
    }
    
}

extension Address: WithdrawableAddress {
    
}

extension TemporaryAddress: WithdrawableAddress {
    
}
