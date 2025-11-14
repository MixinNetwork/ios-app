import UIKit

final class Web3MessageCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var messageTextView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        messageTextView.textContainerInset = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        messageTextView.textContainer.lineFragmentPadding = 0
        messageTextView.textContainer.maximumNumberOfLines = 5
        messageTextView.font = .systemFont(ofSize: 16)
        messageTextView.layer.borderWidth = 1
        messageTextView.layer.cornerRadius = 13
        messageTextView.layer.masksToBounds = true
        updateBorderColor()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }
    
    func updateBorderColor() {
        let color = R.color.background_secondary()!.resolvedColor(with: traitCollection)
        messageTextView.layer.borderColor = color.cgColor
    }
    
}
