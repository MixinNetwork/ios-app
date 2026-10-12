import UIKit
import MixinServices

extension Web3Transaction {
    
    enum Color {
        static let send = R.color.market_red()!
        static let receive = R.color.market_green()!
        static let unavailable = R.color.text_secondary()!
    }
    
    func amountColors() -> (send: UIColor, receive: UIColor) {
        switch status {
        case .pending, .failed, .notFound:
            (Color.unavailable, Color.unavailable)
        case .success:
            (Color.send, Color.receive)
        }
    }
    
}
