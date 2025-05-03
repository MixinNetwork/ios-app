import Foundation
import MixinServices

protocol InvoicePaymentOperationTransaction {
    
    var entry: Invoice.Entry { get }
    var token: MixinTokenItem { get }
    
}

protocol InvoicePaymentOperation {
    
    associatedtype Transaction: InvoicePaymentOperationTransaction
    
    var destination: Payment.TransferDestination { get }
    var transactions: [Transaction] { get }
    
    func start(pin: String) async throws
    
}
