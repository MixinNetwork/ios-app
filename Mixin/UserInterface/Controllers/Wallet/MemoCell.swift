import UIKit

class MemoCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let clearView = UIView()
        clearView.backgroundColor = .clear
        selectedBackgroundView = clearView
    }
    
    @IBAction func copyContent(_ sender: Any) {
        UIPasteboard.general.string = contentLabel.text
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
