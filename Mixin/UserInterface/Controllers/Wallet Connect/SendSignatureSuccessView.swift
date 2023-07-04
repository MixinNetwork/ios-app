import UIKit

final class SendSignatureSuccessView: UIStackView {
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var doneButton: RoundedButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setCustomSpacing(40, after: label)
        if #available(iOS 15.0, *) {
            doneButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 38, bottom: 12, trailing: 38)
        } else {
            doneButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 38, bottom: 12, right: 38)
        }
    }
    
}
