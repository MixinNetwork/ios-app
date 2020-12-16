import UIKit

class AnnouncementBadgeContentView: UIView {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    
    weak var minHeightConstraint: NSLayoutConstraint!
    
    var isExpandable: Bool {
        if let moreView = moreViewIfLoaded {
            return !moreView.isHidden
        } else {
            return false
        }
    }
    
    private let multilineLabelTopMargin: CGFloat = 16
    private let singleLineLabelTopMargin: CGFloat = 24
    
    private lazy var tapCoordinator = TapCoordinator(closeButton: closeButton)
    
    private lazy var moreView: MoreView = {
        let view = MoreView()
        view.label.font = scaledFont
        view.label.adjustsFontForContentSizeCategory = true
        insertSubview(view, aboveSubview: textView)
        view.snp.makeConstraints { (make) in
            make.trailing.equalTo(textView)
        }
        let bottomConstraint = view.bottomAnchor.constraint(equalTo: textView.bottomAnchor)
        let leadingConstraint = view.leadingAnchor.constraint(equalTo: textView.leadingAnchor)
        leadingConstraint.priority = .defaultLow
        NSLayoutConstraint.activate([bottomConstraint, leadingConstraint])
        moreViewBottomConstraint = bottomConstraint
        moreViewLeadingConstraint = leadingConstraint
        moreViewIfLoaded = view
        return view
    }()
    
    private weak var moreViewIfLoaded: MoreView?
    private weak var moreViewBottomConstraint: NSLayoutConstraint?
    private weak var moreViewLeadingConstraint: NSLayoutConstraint?
    
    private var scaledFont: UIFont {
        UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.font = scaledFont
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [.foregroundColor: UIColor.theme]
        minHeightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        minHeightConstraint.isActive = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 4
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(expandIfAvailable))
        tapRecognizer.delegate = tapCoordinator
        addGestureRecognizer(tapRecognizer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = CGPath(roundedRect: backgroundView.frame,
                          cornerWidth: backgroundView.layer.cornerRadius,
                          cornerHeight: backgroundView.layer.cornerRadius,
                          transform: nil)
        layer.shadowPath = path
    }
    
    @objc func expandIfAvailable() {
        guard isExpandable else {
            return
        }
        textView.isSelectable = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.isScrollEnabled = true
        moreViewIfLoaded?.isHidden = true
        textView.invalidateIntrinsicContentSize()
        textViewHeightConstraint.constant = textView.contentSize.height
        textView.setContentOffset(.zero, animated: false)
    }
    
    func layoutAsCompressed() {
        layoutIfNeeded()
        textView.textContainer.maximumNumberOfLines = 2
        textView.isScrollEnabled = false
        
        // Returns maximum number count of 3 on multilines
        let (numberOfLines, lastVisibleLineRect) = { () -> (Int, CGRect) in
            var numberOfLines = 0
            var glyphIndex = 0
            var lineRange = NSRange()
            var lastVisibleLineRect = CGRect.zero
            while glyphIndex < textView.layoutManager.numberOfGlyphs {
                let rect = textView.layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
                glyphIndex = NSMaxRange(lineRange)
                numberOfLines += 1
                if numberOfLines > 2 {
                    return (numberOfLines, lastVisibleLineRect)
                } else {
                    lastVisibleLineRect = rect
                }
            }
            return (numberOfLines, lastVisibleLineRect)
        }()
        
        if numberOfLines > 1 {
            textViewTopConstraint.constant = multilineLabelTopMargin
        } else {
            textViewTopConstraint.constant = singleLineLabelTopMargin
        }
        if numberOfLines > 2 {
            moreView.isHidden = false
            textView.isSelectable = false
        } else {
            moreViewIfLoaded?.isHidden = true
            textView.isSelectable = true
        }
        
        let contentHeight = ceil(scaledFont.lineHeight * CGFloat(min(2, numberOfLines)))
        textViewHeightConstraint.constant = contentHeight
        superview?.layoutIfNeeded()
        moreViewBottomConstraint?.constant = -(textView.frame.height - contentHeight)
        moreViewLeadingConstraint?.constant = round(lastVisibleLineRect.width)
    }
    
}

extension AnnouncementBadgeContentView {
    
    private final class TapCoordinator: NSObject, UIGestureRecognizerDelegate {
        
        private unowned var closeButton: UIView!
        
        init(closeButton: UIView) {
            self.closeButton = closeButton
            super.init()
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let location = gestureRecognizer.location(in: closeButton)
            return !closeButton.bounds.contains(location)
        }
        
    }
    
    private final class MoreView: UIView {
        
        let label = UILabel()
        
        private let gradientWidth: CGFloat = 40
        private let spacing: CGFloat = 10
        private let gradientLayer = CAGradientLayer()
        private let spacingLayer = CALayer()
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            prepare()
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            prepare()
        }
        
        override var intrinsicContentSize: CGSize {
            let labelSize = label.intrinsicContentSize
            let size = CGSize(width: gradientWidth + spacing + labelSize.width,
                              height: labelSize.height)
            return size
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            gradientLayer.frame = CGRect(x: 0, y: 0, width: gradientWidth, height: bounds.height)
            spacingLayer.frame = CGRect(x: gradientLayer.frame.maxX,
                                        y: 0,
                                        width: spacing,
                                        height: bounds.height)
            label.frame = CGRect(x: spacingLayer.frame.maxX,
                                 y: 0,
                                 width: label.intrinsicContentSize.width,
                                 height: label.intrinsicContentSize.height)
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            updateColors()
        }
        
        private func prepare() {
            backgroundColor = .clear
            label.backgroundColor = .background
            label.textColor = .theme
            label.text = R.string.localizable.action_more()
            addSubview(label)
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            gradientLayer.locations = [0, 0.3917, 1]
            updateColors()
            layer.addSublayer(gradientLayer)
            layer.addSublayer(spacingLayer)
        }
        
        private func updateColors() {
            spacingLayer.backgroundColor = UIColor.background.cgColor
            gradientLayer.colors = [0, 0.6024, 1].map({
                UIColor.background.withAlphaComponent($0).cgColor
            })
        }
        
    }
    
}
