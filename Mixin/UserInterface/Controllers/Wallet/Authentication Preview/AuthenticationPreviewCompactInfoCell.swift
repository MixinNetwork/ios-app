import UIKit

final class AuthenticationPreviewCompactInfoCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    
    private let labelLeadingMargin: CGFloat = 6
    private let labelTopMargin: CGFloat = 6
    
    private weak var label: InsetLabel?
    private weak var labelLeadingConstraint: NSLayoutConstraint?
    private weak var labelTopConstraint: NSLayoutConstraint?
    
    private var stackViewBottomMargin: CGFloat = 0
    private var contentTextViewSizeObserver: NSKeyValueObservation?
    private var labelContent: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.adjustsFontForContentSizeCategory = true
        contentTextViewSizeObserver = contentTextView.observe(\.contentSize, options: [.new]) { [weak self] textView, _ in
            self?.layoutLabelIfNeeded()
        }
        stackViewBottomMargin = stackViewBottomConstraint.constant
    }
    
    func setContent(_ content: String, labelContent: String? = nil) {
        self.labelContent = labelContent
        contentTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16))
        contentTextView.text = content
    }
    
    func setBoldContent(_ content: String) {
        self.labelContent = nil
        contentTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
        contentTextView.text = content
    }
    
    func setInscriptionInfo(caption: String, content: Any?) {
        backgroundColor = .clear
        captionLabel.text = caption.uppercased()
        contentTextView.textColor = .white
        if let content {
            setContent("\(content)")
        } else {
            setContent("")
        }
    }
    
    private func layoutLabelIfNeeded() {
        guard let labelContent else {
            label?.removeFromSuperview()
            label = nil
            return
        }
        
        let label: InsetLabel
        if let theLabel = self.label, theLabel.superview != nil {
            label = theLabel
        } else {
            label = InsetLabel()
            label.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
            label.backgroundColor = UIColor(rgbValue: 0x8DCC99)
            label.textColor = .white
            label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingMiddle
            label.layer.masksToBounds = true
            label.layer.cornerRadius = 4
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            self.label = label
        }
        label.text = labelContent
        let labelSize = label.intrinsicContentSize
        
        let trailingLabelOrigin: CGPoint? // Value is nil if trailing space is not enough for the label
        if let positionBeforeEnd = contentTextView.position(from: contentTextView.endOfDocument, offset: -1),
           let range = contentTextView.textRange(from: positionBeforeEnd, to: contentTextView.endOfDocument)
        {
            let lastCharacterFrame = contentTextView.firstRect(for: range)
            if lastCharacterFrame.origin.x.isFinite,
               lastCharacterFrame.origin.y.isFinite,
               contentTextView.bounds.width - lastCharacterFrame.maxX - labelLeadingMargin >= ceil(labelSize.width)
            {
                trailingLabelOrigin = CGPoint(x: lastCharacterFrame.maxX + labelLeadingMargin,
                                              y: lastCharacterFrame.minY + (lastCharacterFrame.height - labelSize.height) / 2)
            } else {
                trailingLabelOrigin = nil
            }
        } else {
            trailingLabelOrigin = nil
        }
        
        let labelLeadingConstraint: NSLayoutConstraint
        let labelTopConstraint: NSLayoutConstraint
        if let leadingConstraint = self.labelLeadingConstraint, let topConstraint = self.labelTopConstraint {
            labelLeadingConstraint = leadingConstraint
            labelTopConstraint = topConstraint
        } else {
            labelLeadingConstraint = label.leadingAnchor.constraint(equalTo: contentTextView.leadingAnchor)
            labelTopConstraint = label.topAnchor.constraint(equalTo: contentTextView.topAnchor)
            let labelTrailingConstraint = label.trailingAnchor.constraint(lessThanOrEqualTo: contentTextView.trailingAnchor)
            NSLayoutConstraint.activate([labelLeadingConstraint, labelTopConstraint, labelTrailingConstraint])
            self.labelLeadingConstraint = labelLeadingConstraint
            self.labelTopConstraint = labelTopConstraint
        }
        
        if let trailingLabelOrigin {
            labelLeadingConstraint.constant = round(trailingLabelOrigin.x)
            labelTopConstraint.constant = round(trailingLabelOrigin.y)
            stackViewBottomConstraint.constant = stackViewBottomMargin
        } else {
            // Place label below content
            labelLeadingConstraint.constant = 0
            labelTopConstraint.constant = round(contentTextView.bounds.height + labelTopMargin)
            stackViewBottomConstraint.constant = ceil(labelTopMargin + labelSize.height + stackViewBottomMargin)
        }
        
        invalidateIntrinsicContentSize()
    }
    
}
