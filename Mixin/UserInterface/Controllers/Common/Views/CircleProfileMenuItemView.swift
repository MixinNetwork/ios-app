import UIKit

final class CircleProfileMenuItemView: ProfileMenuItemView {
    
    override var nibName: String {
        "ProfileMenuItemView"
    }
    
    var names: [String] = [] {
        didSet {
            reloadCircles(with: names)
        }
    }
    
    private let separator = UIView()
    
    private var reusableLabels: Set<InsetLabel> = []
    private var circleNameLabels: Set<InsetLabel> = []
    
    override func prepare() {
        super.prepare()
        label.text = R.string.localizable.circle_title()
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        subtitleLabel.removeFromSuperview()
        separator.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.addArrangedSubview(separator)
    }
    
    private func reloadCircles(with names: [String]) {
        for label in circleNameLabels {
            label.removeFromSuperview()
        }
        reusableLabels = circleNameLabels
        circleNameLabels = []
        for name in names {
            let label = dequeueReusableLabel()
            label.text = name
            label.sizeToFit()
            if label.frame.width < separator.frame.width + stackView.spacing * 2 {
                label.layer.cornerRadius = label.bounds.height / 2
                stackView.addArrangedSubview(label)
                stackView.layoutIfNeeded()
            } else {
                break
            }
        }
    }
    
    private func dequeueReusableLabel() -> InsetLabel {
        if let label = reusableLabels.first {
            return label
        } else {
            let label = InsetLabel()
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            label.textColor = .accessoryText
            label.contentInset = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
            label.layer.borderColor = R.color.line()!.cgColor
            label.layer.borderWidth = 1
            label.layer.masksToBounds = true
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return label
        }
    }
    
}
