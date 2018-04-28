import UIKit

class GroupAnnouncementCell: UITableViewCell {
    
    @IBOutlet weak var textView: CollapsingTextView!
    @IBOutlet weak var emptyAnnouncementPlaceholderLabel: UILabel!
    
    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    
    private var announcement = ""
    
    var height: CGFloat {
        if announcement.isEmpty {
            return 44
        } else {
            layoutIfNeeded()
            return textView.intrinsicContentSize.height + textViewTopConstraint.constant * 2
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let padding = textView.textContainer.lineFragmentPadding
        textView.textContainerInset = UIEdgeInsets(top: 0, left: -padding, bottom: 0, right: -padding)
    }
    
    func render(announcement: String, showDisclosureIndicator: Bool) {
        self.announcement = announcement
        if announcement.isEmpty {
            textView.isHidden = true
            emptyAnnouncementPlaceholderLabel.isHidden = false
        } else {
            textView.text = announcement
            textView.isHidden = false
            emptyAnnouncementPlaceholderLabel.isHidden = true
        }
        accessoryType = showDisclosureIndicator ? .disclosureIndicator : .none
    }
    
}
