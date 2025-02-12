import Foundation

struct BIP21 {
    
    let destination: String
    let amount: Decimal?
    
    init?(string: String) {
        guard let components = URLComponents(string: string) else {
            return nil
        }
        guard components.scheme?.lowercased() == "bitcoin" else {
            return nil
        }
        let amountValue = components.queryItems?.first(where: { $0.name == "amount" })?.value
        self.destination = components.path
        if let amountValue, let amount = Decimal(string: amountValue, locale: .enUSPOSIX) {
            self.amount = amount
        } else {
            self.amount = nil
        }
    }
    
}
