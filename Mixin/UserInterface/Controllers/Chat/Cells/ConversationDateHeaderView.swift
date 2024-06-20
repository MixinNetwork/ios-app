import UIKit
import MixinServices

class ConversationDateHeaderView: UITableViewHeaderFooterView {
    
    static let height: CGFloat = 44
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundConfiguration = .clear()
        updateFontSize()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        alpha = 1
        updateFontSize()
    }
    
    private func updateFontSize() {
        label.font = MessageFontSet.systemMessage.scaled
    }
    
}
