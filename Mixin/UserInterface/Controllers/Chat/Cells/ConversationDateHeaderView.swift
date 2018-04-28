import UIKit

class ConversationDateHeaderView: UITableViewHeaderFooterView {
    
    static let height: CGFloat = 44
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var label: UILabel!

    var contentAlpha: CGFloat = 1 {
        didSet {
            backgroundImageView.alpha = contentAlpha
            label.alpha = contentAlpha
        }
    }
    
}
