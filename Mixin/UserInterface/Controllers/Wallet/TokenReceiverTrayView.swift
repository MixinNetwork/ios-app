import UIKit

final class TokenReceiverTrayView: UIView {
    
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var nextButton: StyledButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        errorDescriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        nextButton.style = .filled
        nextButton.setTitle(R.string.localizable.next(), for: .normal)
    }
    
}
