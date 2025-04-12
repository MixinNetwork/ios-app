import UIKit
import MixinServices

final class Web3TransactionStatusLabel: InsetLabel {
    
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
            textColor = UIColor(displayP3RgbValue: 0x0FB321)
            backgroundColor = UIColor(displayP3RgbValue: 0x50BD5C, alpha: 0.2)
        case .failed:
            text = R.string.localizable.canceled()
            textColor = UIColor(displayP3RgbValue: 0xF67070)
            backgroundColor = UIColor(displayP3RgbValue: 0xF67070, alpha: 0.2)
        case .pending:
            text = R.string.localizable.pending()
            textColor = R.color.text_secondary()
            backgroundColor = R.color.button_background_disabled()
        case .notFound:
            text = R.string.localizable.expired()
            textColor = UIColor(displayP3RgbValue: 0xF67070)
            backgroundColor = UIColor(displayP3RgbValue: 0xF67070, alpha: 0.2)
        }
    }
    
    private func prepare() {
        contentInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        layer.cornerRadius = 4
        layer.masksToBounds = true
    }
    
}
