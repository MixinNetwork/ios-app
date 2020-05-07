import UIKit

class AnnouncementBadgeContentView: UIView {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    
    weak var minHeightConstraint: NSLayoutConstraint!
    
    var isExpandable: Bool {
        if let moreView = moreViewIfLoaded {
            return !moreView.isHidden
        } else {
            return false
        }
    }
    
    private let multilineLabelTopMargin: CGFloat = 16
    private let singleLineLabelTopMargin: CGFloat = 9
    
    private lazy var tapCoordinator = TapCoordinator(closeButton: closeButton)
    
    private lazy var moreView: MoreView = {
        let view = MoreView()
        insertSubview(view, aboveSubview: label)
        view.snp.makeConstraints { (make) in
            make.trailing.equalTo(label)
        }
        moreViewBottomConstraint = view.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        moreViewBottomConstraint!.isActive = true
        moreViewIfLoaded = view
        return view
    }()
    
    private weak var moreViewIfLoaded: MoreView?
    private weak var moreViewBottomConstraint: NSLayoutConstraint?
    
    override func awakeFromNib() {
        super.awakeFromNib()
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
        label.numberOfLines = 0
        moreViewIfLoaded?.isHidden = true
        layoutIfNeeded()
        scrollViewHeightConstraint.constant = scrollView.contentSize.height
    }
    
    func layoutAsCompressed() {
        layoutIfNeeded()
        label.numberOfLines = 2
        guard let text = label.text, !text.isEmpty else {
            scrollViewTopConstraint.constant = singleLineLabelTopMargin
            return
        }
        let fittingSize = CGSize(width: label.frame.width,
                                 height: UIView.layoutFittingExpandedSize.height)
        let size = (text as NSString).boundingRect(with: fittingSize,
                                                   options: .usesLineFragmentOrigin,
                                                   attributes: [.font: label.font!],
                                                   context: nil)
        let lineHeight = label.font.lineHeight
        if size.height - lineHeight > 1 {
            scrollViewTopConstraint.constant = multilineLabelTopMargin
        } else {
            scrollViewTopConstraint.constant = singleLineLabelTopMargin
        }
        if size.height - lineHeight * 2 > 1 {
            moreView.isHidden = false
        } else {
            moreViewIfLoaded?.isHidden = true
        }
        superview?.layoutIfNeeded()
        scrollViewHeightConstraint.constant = scrollView.contentSize.height
        moreViewBottomConstraint?.constant = -(label.bounds.height - min(size.height, lineHeight * 2)) / 2
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
        
        private let gradientWidth: CGFloat = 40
        private let spacing: CGFloat = 10
        private let gradientLayer = CAGradientLayer()
        private let spacingLayer = CALayer()
        private let label = UILabel()
        
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
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
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
