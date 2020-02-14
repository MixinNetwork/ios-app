import UIKit

class PermissionsTableViewCell: ModernSelectedBackgroundCell {

    @IBOutlet weak var scopeNameLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    func render(name: String, desc: String) {
        scopeNameLabel.text = name
        contentLabel.text = desc
    }
    
}
