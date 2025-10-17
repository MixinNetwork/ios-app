import UIKit

final class CommonWalletReceiverCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    weak var userItemView: PaymentUserItemView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let userItemView = R.nib.paymentUserItemView(withOwner: nil)!
        contentStackView.insertArrangedSubview(userItemView, at: 1)
        self.userItemView = userItemView
        contentStackView.setCustomSpacing(10, after: captionLabel)
        contentStackView.setCustomSpacing(6, after: userItemView)
        captionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        addressLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
}
