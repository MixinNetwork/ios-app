import Foundation

struct BIP21 {
    
    let destination: String
    
    init?(string: String) {
        guard let components = URLComponents(string: string) else {
            return nil
        }
        guard components.scheme?.lowercased() == "bitcoin" else {
            return nil
        }
        self.destination = components.path
    }
    
}
