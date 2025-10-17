import UIKit

final class AuthenticationPreviewCompactInfoCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var contentTextView: UITextView!
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    private let labelLeadingMargin: CGFloat = 6
    private let labelTopMargin: CGFloat = 6
    
    private weak var label: InsetLabel?
    private weak var labelLeadingConstraint: NSLayoutConstraint?
    private weak var labelTopConstraint: NSLayoutConstraint?
    
    private var stackViewBottomMargin: CGFloat = 0
    private var contentTextViewSizeObserver: NSKeyValueObservation?
    private var labelContent: AddressLabel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentTextView.textContainerInset = .zero
        contentTextView.textContainer.lineFragmentPadding = 0
        contentTextView.adjustsFontForContentSizeCategory = true
        contentTextViewSizeObserver = contentTextView.observe(\.contentSize, options: [.new]) { [weak self] textView, _ in
            self?.layoutLabelIfNeeded()
        }
        stackViewBottomMargin = contentBottomConstraint.constant
    }
    
    func setContent(_ content: String, labelContent: AddressLabel? = nil) {
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
        selectionStyle = .none
        captionLabel.textColor = UIColor(displayP3RgbValue: 0x999999)
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
        switch labelContent {
        case .addressBook(let text):
            label.backgroundColor = R.color.address_label()
            label.text = text
        case .wallet(let wallet):
            label.backgroundColor = R.color.background_tinted()!.withAlphaComponent(0.7)
            label.text = wallet.localizedName
        case .contact:
            assertionFailure("Use CommonWalletReceiverCell?")
        }
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
            contentBottomConstraint.constant = stackViewBottomMargin
        } else {
            // Place label below content
            labelLeadingConstraint.constant = 0
            labelTopConstraint.constant = round(contentTextView.bounds.height + labelTopMargin)
            contentBottomConstraint.constant = ceil(labelTopMargin + labelSize.height + stackViewBottomMargin)
        }
        
        invalidateIntrinsicContentSize()
    }
    
}
