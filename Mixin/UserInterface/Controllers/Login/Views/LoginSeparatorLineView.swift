import UIKit

final class LoginSeparatorLineView: UIStackView {
    
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.text = R.string.localizable.or()
    }
    
}
