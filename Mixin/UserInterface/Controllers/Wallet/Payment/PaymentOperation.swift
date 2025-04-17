
public protocol PaymentOperation {
    
    func start(pin: String) async throws
}
