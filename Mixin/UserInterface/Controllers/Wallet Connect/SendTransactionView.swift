import UIKit

final class SendTransactionView: UIStackView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var sendButton: RoundedButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setCustomSpacing(12, after: imageView)
        setCustomSpacing(24, after: label)
    }
    
}
