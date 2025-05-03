import Foundation

public class PaymentResponse: Decodable {
    
    public let status: UnknownableEnum<PaymentStatus>
    
}
