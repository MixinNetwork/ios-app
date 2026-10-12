import UIKit
import MixinServices

extension SafeSnapshot {
    
    enum Color {
        static let send = R.color.market_red()!
        static let receive = R.color.market_green()!
        static let pending = R.color.text_secondary()!
    }
    
    func amountColor() -> UIColor {
        switch SnapshotType(rawValue: type) {
        case .pending:
            Color.pending
        default:
            if let withdrawal, withdrawal.hash.isEmpty {
                Color.pending
            } else if amount.hasMinusPrefix {
                Color.send
            } else {
                Color.receive
            }
        }
    }
    
}
