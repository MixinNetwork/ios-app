import UIKit
import MixinServices

final class TransactionStatusLabel: InsetLabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    func load(status: Web3Transaction.Status) {
        switch status {
        case .success:
            text = R.string.localizable.completed()
            setColor(.green)
        case .failed:
            text = R.string.localizable.failed()
            setColor(.red)
        case .pending:
            text = R.string.localizable.pending()
            setColor(.gray)
        case .notFound:
            text = R.string.localizable.expired()
            setColor(.red)
        }
    }
    
    func load(status: UnknownableEnum<MembershipOrder.Status>) {
        text = status.localizedDescription
        switch status.knownCase {
        case .initial:
            setColor(.gray)
        case .paid:
            setColor(.green)
        case .cancel, .expired, .failed, .none:
            setColor(.red)
        }
    }
    
}

extension TransactionStatusLabel {
    
    private enum Color {
        case red, green, gray
    }
    
    private func setColor(_ color: Color) {
        switch color {
        case .red:
            textColor = UIColor(displayP3RgbValue: 0xF67070)
            backgroundColor = UIColor(displayP3RgbValue: 0xF67070, alpha: 0.2)
        case .green:
            textColor = UIColor(displayP3RgbValue: 0x0FB321)
            backgroundColor = UIColor(displayP3RgbValue: 0x50BD5C, alpha: 0.2)
        case .gray:
            textColor = R.color.text_secondary()
            backgroundColor = R.color.button_background_disabled()
        }
    }
    
    private func prepare() {
        contentInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        layer.cornerRadius = 4
        layer.masksToBounds = true
    }
    
}
