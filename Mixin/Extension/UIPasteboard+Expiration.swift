import UIKit
import UniformTypeIdentifiers

extension UIPasteboard {
    
    func setString(_ string: String, expireAfter seconds: TimeInterval) {
        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date(timeIntervalSinceNow: seconds),
        ]
        let item: [String: Any] = [
            UTType.plainText.identifier: string,
        ]
        setItems([item], options: options)
    }
    
}
