import UIKit

class UnreadHintMessageCell: UITableViewCell {

    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.font = MessageFontSet.systemMessage.scaled
    }
    
}
