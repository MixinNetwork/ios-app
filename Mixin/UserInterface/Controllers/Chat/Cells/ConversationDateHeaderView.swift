import UIKit

class ConversationDateHeaderView: UITableViewHeaderFooterView {
    
    static let height: CGFloat = 44
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        alpha = 1
    }
    
}
