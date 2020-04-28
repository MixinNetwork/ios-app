import UIKit

class PermissionsTableViewCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var scopeNameLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    
    func render(name: String, desc: String) {
        scopeNameLabel.text = name
        contentLabel.text = desc
    }
    
}
