import UIKit

final class BadgeBarButtonView: UIView {
    
    enum Badge: Equatable {
        case unread
        case count(Int)
    }
    
    let button = UIButton(type: .system)
    
    var badge: Badge? {
        didSet {
            reload(badge: badge)
        }
    }
    
    private let badgeLabel = BadgeLabel()
    
    private weak var badgeCenterXConstraint: NSLayoutConstraint!
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 46, height: 44)
    }
    
    init(image: UIImage, target: Any, action: Selector) {
        let frame = CGRect(x: 0, y: 0, width: 46, height: 44)
        super.init(frame: frame)
        clipsToBounds = false
        addSubviews()
        button.setImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubviews()
    }
    
    private func addSubviews() {
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        
        badgeLabel.isHidden = true
        badgeLabel.layer.masksToBounds = true
        badgeLabel.font = .systemFont(ofSize: 12)
        badgeLabel.textAlignment = .center
        badgeLabel.textColor = .white
        addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(badgeLabel.snp.height)
            make.centerY.equalToSuperview().offset(-8)
        }
        badgeCenterXConstraint = badgeLabel.centerXAnchor.constraint(
            equalTo: centerXAnchor,
            constant: 10
        )
        badgeCenterXConstraint.isActive = true
    }
    
    private func reload(badge: Badge?) {
        switch badge {
        case .unread:
            badgeLabel.backgroundColor = R.color.error_red()
            badgeLabel.contentInset = .zero
            badgeLabel.text = nil
            badgeLabel.isHidden = false
        case .count(let count):
            badgeLabel.backgroundColor = R.color.theme()
            badgeLabel.contentInset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
            badgeLabel.text = "\(count)"
            badgeLabel.isHidden = false
        case nil:
            badgeLabel.isHidden = true
        }
    }
    
}

extension BadgeBarButtonView {
    
    private final class BadgeLabel: InsetLabel {
        
        override var text: String? {
            didSet {
                invalidateIntrinsicContentSize()
            }
        }
        
        override var intrinsicContentSize: CGSize {
            if let text, !text.isEmpty {
                super.intrinsicContentSize
            } else {
                CGSize(width: 8, height: 8)
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
        
    }
    
}
