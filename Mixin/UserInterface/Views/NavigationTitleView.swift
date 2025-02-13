import UIKit

final class NavigationTitleView: UIStackView {
    
    enum SubtitleStyle {
        case plain
        case label(backgroundColor: UIColor)
    }
    
    private(set) weak var titleLabel: UILabel!
    private(set) weak var subtitleLabel: InsetLabel!
    
    var subtitle: String? {
        get {
            subtitleLabel.text
        }
        set {
            layoutLabels(subtitle: newValue)
        }
    }
    
    var subtitleStyle: SubtitleStyle = .plain {
        didSet {
            switch subtitleStyle {
            case .plain:
                subtitleLabel.contentInset = .zero
                subtitleLabel.backgroundColor = .clear
                subtitleLabel.textColor = R.color.text_quaternary()
                subtitleLabel.layer.cornerRadius = 0
            case .label(let backgroundColor):
                subtitleLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
                subtitleLabel.backgroundColor = backgroundColor
                subtitleLabel.textColor = .white
                subtitleLabel.layer.cornerRadius = 4
            }
        }
    }
    
    init(title: String, subtitle: String? = nil) {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .center
        spacing = 2
        
        let titleLabel = {
            let label = UILabel()
            label.textColor = R.color.text()
            label.text = title
            return label
        }()
        addArrangedSubview(titleLabel)
        self.titleLabel = titleLabel
        
        let subtitleLabel = {
            let label = InsetLabel()
            label.backgroundColor = .clear
            label.layer.masksToBounds = true
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = R.color.text_quaternary()
            label.text = subtitle
            return label
        }()
        addArrangedSubview(subtitleLabel)
        self.subtitleLabel = subtitleLabel
        
        layoutLabels(subtitle: subtitle)
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    private func layoutLabels(subtitle: String?) {
        if let subtitle, !subtitle.isEmpty {
            titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
            subtitleLabel.isHidden = true
        }
    }
    
}
