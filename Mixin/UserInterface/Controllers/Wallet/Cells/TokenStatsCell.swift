import UIKit

final class TokenStatsCell: UITableViewCell {
    
    @IBOutlet weak var leftTitleLabel: UILabel!
    @IBOutlet weak var rightTitleLabel: UILabel!
    @IBOutlet weak var leftContentLabel: UILabel!
    @IBOutlet weak var rightContentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leftContentLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
        rightContentLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .medium), adjustForContentSize: true)
    }
    
    func setLeftContent(text: String?) {
        setContent(forLabel: leftContentLabel, text: text)
    }
    
    func setRightContent(text: String?) {
        setContent(forLabel: rightContentLabel, text: text)
    }
    
    private func setContent(forLabel label: UILabel, text: String?) {
        if let text {
            label.text = text
            label.textColor = R.color.text()
        } else {
            label.text = notApplicable
            label.textColor = R.color.text_tertiary()
        }
    }
    
}
