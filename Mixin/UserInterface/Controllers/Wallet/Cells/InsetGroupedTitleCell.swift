import UIKit

final class InsetGroupedTitleCell: UITableViewCell {
    
    enum Subtitle {
        case rank(String)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var disclosureIndicatorView: UIImageView!
    
    var subtitle: Subtitle? {
        didSet {
            reloadSubtitle(subtitle)
        }
    }
    
    private weak var rankLabel: InsetLabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    private func reloadSubtitle(_ subtitle: Subtitle?) {
        switch subtitle {
        case .rank(let rank):
            let label: InsetLabel
            if let rankLabel {
                label = rankLabel
            } else {
                label = InsetLabel()
                label.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
                label.backgroundColor = R.color.background_tag()
                label.textColor = R.color.text_tertiary()
                label.font = .systemFont(ofSize: 12)
                label.layer.masksToBounds = true
                label.layer.cornerRadius = 4
                contentStackView.insertArrangedSubview(label, at: 1)
                self.rankLabel = label
            }
            label.text = rank
        case nil:
            rankLabel?.removeFromSuperview()
        }
    }
    
}
