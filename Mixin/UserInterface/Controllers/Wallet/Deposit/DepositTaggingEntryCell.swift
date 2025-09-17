import UIKit
import MixinServices

final class DepositTaggingEntryCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var iconBackgroundView: UIView!
    @IBOutlet weak var iconView: BadgeIconView!
    
    @IBOutlet weak var qrCodeDimensionConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconBackgroundDimensionConstraint: NSLayoutConstraint!
    
    weak var delegate: DepositEntryActionDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        warningLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        qrCodeView.setDefaultCornerCurve()
        iconBackgroundView.layer.cornerRadius = iconBackgroundDimensionConstraint.constant / 2
        iconBackgroundView.layer.masksToBounds = true
    }
    
    @IBAction func sendCopyAction(_ sender: Any) {
        delegate?.depositEntryCell(self, didRequestAction: .copy)
    }
    
    func load<Token: OnChainToken>(
        content: DepositViewModel.Entry.Content,
        token: Token,
    ) {
        titleLabel.text = content.title
        contentLabel.text = content.textValue
        warningLabel.text = content.warning
        let qrCodeSize = CGSize(
            width: qrCodeDimensionConstraint.constant,
            height: qrCodeDimensionConstraint.constant
        )
        qrCodeView.setContent(content.qrCodeValue, size: qrCodeSize)
        iconView.setIcon(token: token, chain: token.chain)
    }
    
}
