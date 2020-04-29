import UIKit

class AnnouncementBadgeContentView: UIView {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var viewButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var labelTopConstraint: NSLayoutConstraint!
    
    private let multilineLabelTopMargin: CGFloat = 16
    private let singleLineLabelTopMargin: CGFloat = 9
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 4
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = CGPath(roundedRect: backgroundView.frame,
                          cornerWidth: backgroundView.layer.cornerRadius,
                          cornerHeight: backgroundView.layer.cornerRadius,
                          transform: nil)
        layer.shadowPath = path
    }
    
    func ensureLayout() {
        layoutIfNeeded()
        guard let text = label.text, !text.isEmpty else {
            labelTopConstraint.constant = singleLineLabelTopMargin
            return
        }
        let fittingSize = CGSize(width: label.frame.width,
                                 height: UIView.layoutFittingExpandedSize.height)
        let size = (text as NSString).boundingRect(with: fittingSize,
                                                   options: .usesLineFragmentOrigin,
                                                   attributes: [.font: label.font!],
                                                   context: nil)
        if size.height - label.font.lineHeight > 1 {
            labelTopConstraint.constant = multilineLabelTopMargin
        } else {
            labelTopConstraint.constant = singleLineLabelTopMargin
        }
        setNeedsLayout()
    }
    
}
